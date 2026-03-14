package com.parksy.studio

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.*
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicInteger

class RecordingService : Service() {

    companion object {
        const val CHANNEL_ID = "parksy_recording"
        const val ACTION_START = "START"
        const val ACTION_STOP = "STOP"
        const val EXTRA_AUDIO_MODE = "audioMode" // "mic" | "unprocessed" | "daw"
        var isRecording = false
        var outputPath = ""
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null

    // 단순 모드 (MediaRecorder — MIC / UNPROCESSED)
    private var mediaRecorder: MediaRecorder? = null

    // DAW 모드 (AudioPlaybackCapture + MediaCodec + MediaMuxer)
    private var audioRecord: AudioRecord? = null
    private var videoCodec: MediaCodec? = null
    private var audioCodec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private val videoTrackIdx = AtomicInteger(-1)
    private val audioTrackIdx = AtomicInteger(-1)
    @Volatile private var muxerStarted = false
    @Volatile private var isDawMode = false
    private var videoThread: Thread? = null
    private var audioThread: Thread? = null

    // ──────────────────────────────────────────────────────────────
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startRecording(intent)
            ACTION_STOP  -> stopRecording()
        }
        return START_NOT_STICKY
    }

    // ──────────────────────────────────────────────────────────────
    private fun startRecording(intent: Intent) {
        createNotificationChannel()
        startForeground(1, buildNotification())

        val resultCode = intent.getIntExtra("resultCode", -1)
        val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra("data", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra("data")
        } ?: run { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return }

        val width  = intent.getIntExtra("width", 1080)
        val height = intent.getIntExtra("height", 1920)
        outputPath = intent.getStringExtra("outputPath") ?: run {
            stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return
        }
        val audioMode = intent.getStringExtra(EXTRA_AUDIO_MODE) ?: "mic"
        isDawMode = audioMode == "daw"

        val projectionMgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projectionMgr.getMediaProjection(resultCode, data)

        if (isDawMode) {
            startDawMode(width, height)
        } else {
            startSimpleMode(width, height, audioMode)
        }
        isRecording = true
    }

    // ── 단순 모드 (MediaRecorder) ──────────────────────────────────
    private fun startSimpleMode(width: Int, height: Int, audioMode: String) {
        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        // UNPROCESSED = AGC/노이즈게이트 우회 (Shure MOTIV 직접 캡처용)
        val audioSource = if (audioMode == "unprocessed")
            MediaRecorder.AudioSource.UNPROCESSED
        else
            MediaRecorder.AudioSource.MIC

        mediaRecorder!!.apply {
            setAudioSource(audioSource)
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setVideoSize(width, height)
            setVideoFrameRate(30)
            setVideoEncodingBitRate(6_000_000)
            // UNPROCESSED: 256kbps / 48kHz — Shure MOTIV 기본 출력
            setAudioEncodingBitRate(if (audioMode == "unprocessed") 256_000 else 128_000)
            setAudioSamplingRate(if (audioMode == "unprocessed") 48_000 else 44_100)
            setOutputFile(outputPath)
            prepare()
        }
        virtualDisplay = mediaProjection!!.createVirtualDisplay(
            "ParksyStudio", width, height,
            resources.displayMetrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            mediaRecorder!!.surface, null, null
        )
        mediaRecorder!!.start()
    }

    // ── DAW 모드 (AudioPlaybackCapture + MediaCodec + MediaMuxer) ──
    private fun startDawMode(width: Int, height: Int) {
        val sampleRate = 44_100
        val channelMask = AudioFormat.CHANNEL_IN_STEREO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        val bufSize = AudioRecord.getMinBufferSize(sampleRate, channelMask, encoding) * 4

        // AudioPlaybackCapture: 시스템 오디오 전부 (BGM + DAW 출력)
        // minSdk 29 (Android 10) → AudioPlaybackCaptureConfiguration 사용 가능
        val playbackCfg = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        audioRecord = AudioRecord.Builder()
            .setAudioPlaybackCaptureConfig(playbackCfg)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelMask)
                    .setEncoding(encoding)
                    .build()
            )
            .setBufferSizeInBytes(bufSize)
            .build()

        // 비디오 인코더 (H.264)
        val vFmt = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 6_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        videoCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        videoCodec!!.configure(vFmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val inputSurface = videoCodec!!.createInputSurface()
        videoCodec!!.start()

        // 오디오 인코더 (AAC)
        val aFmt = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 2).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, 192_000)
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, bufSize)
        }
        audioCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        audioCodec!!.configure(aFmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        audioCodec!!.start()

        // Muxer
        muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        muxerStarted = false
        videoTrackIdx.set(-1)
        audioTrackIdx.set(-1)

        // VirtualDisplay → 비디오 코덱 surface
        virtualDisplay = mediaProjection!!.createVirtualDisplay(
            "ParksyStudio", width, height,
            resources.displayMetrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            inputSurface, null, null
        )

        audioRecord!!.startRecording()

        // ── 오디오 스레드 ──────────────────────────────────────────
        audioThread = Thread {
            val pcm = ByteArray(bufSize)
            val startUs = System.nanoTime() / 1000L
            while (isRecording) {
                val read = audioRecord!!.read(pcm, 0, pcm.size)
                if (read <= 0) continue
                val ac = audioCodec ?: break
                val inIdx = ac.dequeueInputBuffer(5_000)
                if (inIdx >= 0) {
                    ac.getInputBuffer(inIdx)!!.apply { clear(); put(pcm, 0, read) }
                    val pts = System.nanoTime() / 1000L - startUs
                    ac.queueInputBuffer(inIdx, 0, read, pts, 0)
                }
                drainAudioCodec()
            }
            // EOS
            audioCodec?.let { ac ->
                val inIdx = ac.dequeueInputBuffer(5_000)
                if (inIdx >= 0) ac.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                drainAudioCodec()
            }
        }.also { it.start() }

        // ── 비디오 스레드 ─────────────────────────────────────────
        videoThread = Thread {
            val info = MediaCodec.BufferInfo()
            while (isRecording) drainVideoCodec(info)
            videoCodec?.signalEndOfInputStream()
            drainVideoCodec(info) // flush
        }.also { it.start() }
    }

    // muxer 트랙 조율: 양쪽 다 등록돼야 start
    @Synchronized
    private fun tryStartMuxer() {
        if (!muxerStarted && videoTrackIdx.get() >= 0 && audioTrackIdx.get() >= 0) {
            muxer?.start()
            muxerStarted = true
        }
    }

    private fun drainAudioCodec() {
        val ac = audioCodec ?: return
        val info = MediaCodec.BufferInfo()
        var outIdx = ac.dequeueOutputBuffer(info, 0)
        while (outIdx >= 0 || outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
            if (outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (audioTrackIdx.get() < 0) {
                    audioTrackIdx.set(muxer!!.addTrack(ac.outputFormat))
                    tryStartMuxer()
                }
            } else if (outIdx >= 0) {
                val buf = ac.getOutputBuffer(outIdx)!!
                val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                if (!isConfig && muxerStarted && audioTrackIdx.get() >= 0 && info.size > 0) {
                    muxer!!.writeSampleData(audioTrackIdx.get(), buf, info)
                }
                ac.releaseOutputBuffer(outIdx, false)
            }
            outIdx = ac.dequeueOutputBuffer(info, 0)
        }
    }

    private fun drainVideoCodec(info: MediaCodec.BufferInfo) {
        val vc = videoCodec ?: return
        val outIdx = vc.dequeueOutputBuffer(info, 10_000)
        when {
            outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                if (videoTrackIdx.get() < 0) {
                    videoTrackIdx.set(muxer!!.addTrack(vc.outputFormat))
                    tryStartMuxer()
                }
            }
            outIdx >= 0 -> {
                val buf = vc.getOutputBuffer(outIdx)!!
                val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                if (!isConfig && muxerStarted && videoTrackIdx.get() >= 0 && info.size > 0) {
                    muxer!!.writeSampleData(videoTrackIdx.get(), buf, info)
                }
                vc.releaseOutputBuffer(outIdx, false)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────
    private fun stopRecording() {
        isRecording = false
        if (isDawMode) {
            audioThread?.join(2_000)
            videoThread?.join(2_000)
            try { audioRecord?.stop() } catch (_: Exception) {}
            audioRecord?.release(); audioRecord = null
            try { videoCodec?.stop() } catch (_: Exception) {}
            videoCodec?.release(); videoCodec = null
            try { audioCodec?.stop() } catch (_: Exception) {}
            audioCodec?.release(); audioCodec = null
            try { if (muxerStarted) muxer?.stop() } catch (_: Exception) {}
            muxer?.release(); muxer = null
        } else {
            try { mediaRecorder?.stop() } catch (_: Exception) {}
            mediaRecorder?.release(); mediaRecorder = null
        }
        virtualDisplay?.release(); virtualDisplay = null
        mediaProjection?.stop(); mediaProjection = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ──────────────────────────────────────────────────────────────
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "화면 녹화", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Parksy Studio 녹화 중")
            .setContentText("탭하여 중지")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    override fun onBind(intent: Intent?): IBinder? = null
}
