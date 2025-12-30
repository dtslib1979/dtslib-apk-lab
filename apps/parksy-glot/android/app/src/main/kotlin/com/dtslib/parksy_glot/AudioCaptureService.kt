package com.dtslib.parksy_glot

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.media.*
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

object AudioCaptureService {
    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var isCapturing = false
    private var captureThread: Thread? = null

    private var projectionResultCode: Int = 0
    private var projectionData: Intent? = null

    private var flutterChannel: MethodChannel? = null

    fun setMediaProjectionData(resultCode: Int, data: Intent) {
        projectionResultCode = resultCode
        projectionData = data
    }

    fun setFlutterChannel(channel: MethodChannel) {
        flutterChannel = channel
    }

    @SuppressLint("MissingPermission")
    @RequiresApi(Build.VERSION_CODES.Q)
    fun startCapture(context: Context, sampleRate: Int, channelCount: Int): Boolean {
        if (isCapturing) return true
        if (projectionData == null) return false

        try {
            val projectionManager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(projectionResultCode, projectionData!!)

            val config = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()

            val audioFormat = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(if (channelCount == 1) AudioFormat.CHANNEL_IN_MONO else AudioFormat.CHANNEL_IN_STEREO)
                .build()

            val bufferSize = AudioRecord.getMinBufferSize(
                sampleRate,
                if (channelCount == 1) AudioFormat.CHANNEL_IN_MONO else AudioFormat.CHANNEL_IN_STEREO,
                AudioFormat.ENCODING_PCM_16BIT
            )

            audioRecord = AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(config)
                .setAudioFormat(audioFormat)
                .setBufferSizeInBytes(bufferSize * 2)
                .build()

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                return false
            }

            audioRecord?.startRecording()
            isCapturing = true

            captureThread = Thread {
                val buffer = ByteArray(bufferSize)
                while (isCapturing) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (read > 0) {
                        // Send audio data to Flutter
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            flutterChannel?.invokeMethod("onAudioData", buffer.copyOf(read))
                        }
                    }
                }
            }
            captureThread?.start()

            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    fun stopCapture() {
        isCapturing = false
        captureThread?.interrupt()
        captureThread = null

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        mediaProjection?.stop()
        mediaProjection = null
    }
}
