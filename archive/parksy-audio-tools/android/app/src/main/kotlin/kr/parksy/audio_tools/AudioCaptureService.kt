package kr.parksy.audio_tools

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * System Audio Capture Service
 * - Foreground Service with MediaProjection
 * - Floating record button overlay
 * - WAV output
 */
class AudioCaptureService : Service() {

    companion object {
        const val TAG = "AudioCaptureService"
        const val CHANNEL_ID = "parksy_audio_capture"
        const val NOTIFICATION_ID = 2001

        const val ACTION_START = "kr.parksy.audio_tools.START"
        const val ACTION_STOP = "kr.parksy.audio_tools.STOP"
        const val ACTION_SHOW = "kr.parksy.audio_tools.SHOW"
        const val ACTION_HIDE = "kr.parksy.audio_tools.HIDE"

        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"

        var instance: AudioCaptureService? = null
        var isRecording = false
        var lastRecordingPath: String? = null
        var pendingPresetSeconds = 60

        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_STEREO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    private var windowManager: WindowManager? = null
    private var floatingButton: FloatingRecordButton? = null
    private var buttonParams: WindowManager.LayoutParams? = null

    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null

    private var elapsedSeconds = 0
    private var presetSeconds = 60
    private val handler = Handler(Looper.getMainLooper())

    private val timerRunnable = object : Runnable {
        override fun run() {
            elapsedSeconds++
            floatingButton?.updateTimer(elapsedSeconds)
            updateNotification()

            if (elapsedSeconds >= presetSeconds) {
                stopRecording()
            } else {
                handler.postDelayed(this, 1000)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        Log.i(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
                val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(EXTRA_DATA)
                }

                presetSeconds = pendingPresetSeconds

                startForeground(NOTIFICATION_ID, createNotification())
                showFloatingButton()

                if (resultCode != -1 && data != null) {
                    startCapture(resultCode, data)
                }
            }
            ACTION_STOP -> stopRecording()
            ACTION_SHOW -> showFloatingButton()
            ACTION_HIDE -> hideFloatingButton()
            else -> startForeground(NOTIFICATION_ID, createNotification())
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopRecording()
        hideFloatingButton()
        instance = null
        super.onDestroy()
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun startCapture(resultCode: Int, data: Intent) {
        if (isRecording) return

        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projectionManager.getMediaProjection(resultCode, data)

        if (mediaProjection == null) {
            Log.e(TAG, "Failed to get MediaProjection")
            return
        }

        val config = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT) * 2

        audioRecord = AudioRecord.Builder()
            .setAudioPlaybackCaptureConfig(config)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AUDIO_FORMAT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(CHANNEL_CONFIG)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .build()

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "AudioRecord initialization failed")
            return
        }

        isRecording = true
        elapsedSeconds = 0
        floatingButton?.setRecording(true)
        handler.post(timerRunnable)

        val outputFile = createOutputFile()
        lastRecordingPath = outputFile.absolutePath

        recordingThread = Thread {
            writeWavFile(outputFile, bufferSize)
        }
        recordingThread?.start()
        audioRecord?.startRecording()

        Log.i(TAG, "Recording started: $lastRecordingPath")
        updateNotification()
    }

    fun stopRecording() {
        if (!isRecording) return

        isRecording = false
        handler.removeCallbacks(timerRunnable)

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        recordingThread?.join(1000)
        recordingThread = null

        mediaProjection?.stop()
        mediaProjection = null

        floatingButton?.setRecording(false)
        Log.i(TAG, "Recording stopped: $lastRecordingPath")

        updateNotification()
    }

    private fun writeWavFile(file: File, bufferSize: Int) {
        val buffer = ByteArray(bufferSize)
        val fos = FileOutputStream(file)

        // Write placeholder header
        fos.write(ByteArray(44))

        var totalBytes = 0L
        while (isRecording) {
            val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
            if (read > 0) {
                fos.write(buffer, 0, read)
                totalBytes += read
            }
        }
        fos.close()

        // Update WAV header
        updateWavHeader(file, totalBytes)
    }

    private fun updateWavHeader(file: File, totalAudioBytes: Long) {
        val channels = 2
        val bitsPerSample = 16
        val byteRate = SAMPLE_RATE * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8

        val raf = RandomAccessFile(file, "rw")
        raf.seek(0)

        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)

        // RIFF header
        header.put("RIFF".toByteArray())
        header.putInt((36 + totalAudioBytes).toInt())
        header.put("WAVE".toByteArray())

        // fmt chunk
        header.put("fmt ".toByteArray())
        header.putInt(16) // Subchunk1Size
        header.putShort(1) // AudioFormat (PCM)
        header.putShort(channels.toShort())
        header.putInt(SAMPLE_RATE)
        header.putInt(byteRate)
        header.putShort(blockAlign.toShort())
        header.putShort(bitsPerSample.toShort())

        // data chunk
        header.put("data".toByteArray())
        header.putInt(totalAudioBytes.toInt())

        raf.write(header.array())
        raf.close()
    }

    private fun createOutputFile(): File {
        val dir = cacheDir
        val timestamp = System.currentTimeMillis()
        return File(dir, "capture_$timestamp.wav")
    }

    // === Floating Button ===

    private fun showFloatingButton() {
        if (floatingButton != null) return

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_PHONE

        buttonParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 16
            y = 200
        }

        floatingButton = FloatingRecordButton(
            context = this,
            onRecordClick = { toggleRecording() },
            onCloseClick = { stopSelfAndClose() },
            onDrag = { dx, dy -> moveButton(dx, dy) }
        )

        windowManager?.addView(floatingButton, buttonParams)
        Log.i(TAG, "Floating button shown")
    }

    private fun hideFloatingButton() {
        try {
            floatingButton?.let { windowManager?.removeView(it) }
        } catch (_: Exception) {}
        floatingButton = null
        buttonParams = null
    }

    private fun moveButton(dx: Int, dy: Int) {
        buttonParams?.let { params ->
            params.x -= dx
            params.y += dy
            try { windowManager?.updateViewLayout(floatingButton, params) } catch (_: Exception) {}
        }
    }

    private fun toggleRecording() {
        // Toggle is handled by Flutter - this is just for direct clicks
        if (isRecording) {
            stopRecording()
        }
    }

    private fun stopSelfAndClose() {
        stopRecording()
        hideFloatingButton()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // === Notification ===

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Audio Capture",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "System audio recording"
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val mainIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, AudioCaptureService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val status = if (isRecording) {
            "🔴 ${formatTime(elapsedSeconds)} / ${formatTime(presetSeconds)}"
        } else {
            "⏸️ 대기"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Parksy Audio Capture")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(mainIntent)
            .addAction(0, if (isRecording) "STOP" else "CLOSE", stopIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, createNotification())
    }

    private fun formatTime(seconds: Int): String {
        val m = seconds / 60
        val s = seconds % 60
        return String.format("%d:%02d", m, s)
    }
}
