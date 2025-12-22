package com.dtslib.overlaydualsub.audio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * 마이크 오디오 캐치 (v1 최소 구현)
 * 
 * - PCM16 mono, 16kHz
 * - 500ms 청크로 큐잉
 * - 코루틴 기반 비동기 캘처
 */
class MicAudioCapturer(private val context: Context) {

    companion object {
        const val SAMPLE_RATE = 16000
        const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        const val CHUNK_MS = 500
    }

    private var audioRecord: AudioRecord? = null
    private var captureJob: Job? = null
    private val audioQueue = ConcurrentLinkedQueue<ByteArray>()

    private val bufferSize: Int by lazy {
        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
        maxOf(minBuf, SAMPLE_RATE * 2) // 최소 1초 버퍼
    }

    private val chunkSize: Int by lazy {
        (SAMPLE_RATE * 2 * CHUNK_MS) / 1000 // bytes per chunk
    }

    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun start() {
        if (!hasPermission()) return
        if (audioRecord != null) return

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL,
                ENCODING,
                bufferSize
            )
            audioRecord?.startRecording()
            startCaptureLoop()
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    fun stop() {
        captureJob?.cancel()
        captureJob = null
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        audioQueue.clear()
    }

    fun pollChunk(): ByteArray? = audioQueue.poll()

    private fun startCaptureLoop() {
        captureJob = CoroutineScope(Dispatchers.IO).launch {
            val buffer = ByteArray(chunkSize)
            while (isActive && audioRecord != null) {
                val read = audioRecord?.read(buffer, 0, chunkSize) ?: 0
                if (read > 0) {
                    audioQueue.offer(buffer.copyOf(read))
                    // 큐 크기 제한 (10개 초과 시 오래된 것 버림)
                    while (audioQueue.size > 10) {
                        audioQueue.poll()
                    }
                }
            }
        }
    }
}
