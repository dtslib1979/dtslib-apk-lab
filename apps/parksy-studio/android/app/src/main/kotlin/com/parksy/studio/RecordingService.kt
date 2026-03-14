package com.parksy.studio

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.*
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
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
        const val ACTION_STOP  = "STOP"
        const val EXTRA_AUDIO_MODE    = "audioMode"    // "mic" | "unprocessed" | "daw"
        const val EXTRA_AUDIO_PROFILE = "audioProfile" // "lecture" | "podcast" | "raw"
        var isRecording = false
        var outputPath  = ""
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null

    // 통합 파이프라인 (AudioRecord + MediaCodec + MediaMuxer)
    // — MIC, UNPROCESSED, DAW 모드 모두 동일 파이프라인 사용
    private var audioRecord: AudioRecord? = null
    private var videoCodec: MediaCodec? = null
    private var audioCodec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private val videoTrackIdx = AtomicInteger(-1)
    private val audioTrackIdx = AtomicInteger(-1)
    @Volatile private var muxerStarted = false
    private var videoThread: Thread? = null
    private var audioThread: Thread? = null

    // AudioEffect references (need to keep reference to prevent GC)
    private var noiseSuppressor: NoiseSuppressor? = null
    private var agc: AutomaticGainControl? = null
    private var aec: AcousticEchoCanceler? = null

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
        val audioMode    = intent.getStringExtra(EXTRA_AUDIO_MODE)    ?: "mic"
        val audioProfile = intent.getStringExtra(EXTRA_AUDIO_PROFILE) ?: "raw"

        val projectionMgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projectionMgr.getMediaProjection(resultCode, data)

        startUnifiedMode(width, height, audioMode, audioProfile)
        isRecording = true
    }

    // ── 통합 파이프라인 (MIC / UNPROCESSED / DAW 공통) ─────────────
    private fun startUnifiedMode(width: Int, height: Int, audioMode: String, audioProfile: String) {
        val sampleRate  = if (audioMode == "unprocessed") 48_000 else 44_100
        val channelMask = AudioFormat.CHANNEL_IN_STEREO
        val encoding    = AudioFormat.ENCODING_PCM_16BIT
        val bufSize     = AudioRecord.getMinBufferSize(sampleRate, channelMask, encoding) * 4

        // ── AudioRecord 생성 ──────────────────────────────────────
        audioRecord = if (audioMode == "daw") {
            // DAW 모드: 시스템 재생 오디오 캡처 (minSdk 29)
            val playbackCfg = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()
            AudioRecord.Builder()
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
        } else {
            // MIC / UNPROCESSED: 마이크 캡처
            val source = if (audioMode == "unprocessed")
                MediaRecorder.AudioSource.UNPROCESSED
            else
                MediaRecorder.AudioSource.MIC
            AudioRecord(source, sampleRate, channelMask, encoding, bufSize)
        }

        // ── AudioEffect 적용 (DAW 모드 제외 — 이미 처리된 오디오) ──
        if (audioMode != "daw") {
            applyAudioEffects(audioRecord!!.audioSessionId, audioProfile)
        }

        // ── 비디오 인코더 (H.264) ─────────────────────────────────
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

        // ── 오디오 인코더 (AAC) ───────────────────────────────────
        val audioBitrate = if (audioMode == "unprocessed") 256_000 else 192_000
        val aFmt = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 2).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, audioBitrate)
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, bufSize)
        }
        audioCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        audioCodec!!.configure(aFmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        audioCodec!!.start()

        // ── Muxer ─────────────────────────────────────────────────
        muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        muxerStarted = false
        videoTrackIdx.set(-1)
        audioTrackIdx.set(-1)

        // ── VirtualDisplay → 비디오 코덱 surface ─────────────────
        virtualDisplay = mediaProjection!!.createVirtualDisplay(
            "ParksyStudio", width, height,
            resources.displayMetrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            inputSurface, null, null
        )

        audioRecord!!.startRecording()

        // ── 오디오 스레드 ─────────────────────────────────────────
        audioThread = Thread {
            val pcm    = ByteArray(bufSize)
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

    // ── AudioEffect 적용 ──────────────────────────────────────────
    private fun applyAudioEffects(sessionId: Int, profile: String) {
        when (profile) {
            "lecture" -> {
                if (NoiseSuppressor.isAvailable()) {
                    noiseSuppressor = NoiseSuppressor.create(sessionId)?.also { it.enabled = true }
                }
                if (AutomaticGainControl.isAvailable()) {
                    agc = AutomaticGainControl.create(sessionId)?.also { it.enabled = true }
                }
                if (AcousticEchoCanceler.isAvailable()) {
                    aec = AcousticEchoCanceler.create(sessionId)?.also { it.enabled = true }
                }
            }
            "podcast" -> {
                if (NoiseSuppressor.isAvailable()) {
                    noiseSuppressor = NoiseSuppressor.create(sessionId)?.also { it.enabled = true }
                }
                if (AutomaticGainControl.isAvailable()) {
                    agc = AutomaticGainControl.create(sessionId)?.also { it.enabled = true }
                }
            }
            // "music", "raw": 이펙트 없음
        }
    }

    // ── Muxer 조율: 비디오 + 오디오 트랙 양쪽 등록 후 start ──────
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

        audioThread?.join(2_000)
        videoThread?.join(2_000)

        // AudioEffect 해제
        noiseSuppressor?.release(); noiseSuppressor = null
        agc?.release(); agc = null
        aec?.release(); aec = null

        try { audioRecord?.stop() } catch (_: Exception) {}
        audioRecord?.release(); audioRecord = null

        try { videoCodec?.stop() } catch (_: Exception) {}
        videoCodec?.release(); videoCodec = null

        try { audioCodec?.stop() } catch (_: Exception) {}
        audioCodec?.release(); audioCodec = null

        try { if (muxerStarted) muxer?.stop() } catch (_: Exception) {}
        muxer?.release(); muxer = null

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
