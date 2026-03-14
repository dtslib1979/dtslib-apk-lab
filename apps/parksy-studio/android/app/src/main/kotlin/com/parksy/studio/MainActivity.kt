package com.parksy.studio

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.os.Environment
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterActivity() {

    private val RECORDING_CHANNEL = "com.parksy.studio/recording"
    private val PROJECTION_REQUEST = 100
    private var pendingResult: MethodChannel.Result? = null
    private var pendingFormat = "shorts"
    private var pendingAudioMode = "mic"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        pendingResult    = result
                        pendingFormat    = call.argument<String>("format")    ?: "shorts"
                        pendingAudioMode = call.argument<String>("audioMode") ?: "mic"
                        requestProjectionPermission()
                    }
                    "stopRecording" -> {
                        stopRecordingService()
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            result.success(RecordingService.outputPath.ifEmpty { null })
                        }, 800) // DAW 모드는 muxer stop에 시간이 더 필요
                    }
                    "isRecording" -> result.success(RecordingService.isRecording)
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestProjectionPermission() {
        val mgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(mgr.createScreenCaptureIntent(), PROJECTION_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PROJECTION_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val outputPath = buildOutputPath(pendingFormat)
                val (width, height) = formatDimensions(pendingFormat)
                val serviceIntent = Intent(this, RecordingService::class.java).apply {
                    action = RecordingService.ACTION_START
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("width", width)
                    putExtra("height", height)
                    putExtra("outputPath", outputPath)
                    putExtra(RecordingService.EXTRA_AUDIO_MODE, pendingAudioMode)
                }
                startForegroundService(serviceIntent)
                pendingResult?.success(outputPath)
            } else {
                pendingResult?.error("PERMISSION_DENIED", "화면녹화 권한 거부", null)
            }
            pendingResult = null
        }
    }

    private fun stopRecordingService() {
        startService(Intent(this, RecordingService::class.java).apply {
            action = RecordingService.ACTION_STOP
        })
    }

    private fun buildOutputPath(format: String): String {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
            "ParksyStudio"
        ).also { it.mkdirs() }
        val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        return "${dir.absolutePath}/PS_${format.uppercase()}_$ts.mp4"
    }

    private fun formatDimensions(format: String): Pair<Int, Int> = when (format) {
        "shorts" -> Pair(1080, 1920)
        "long"   -> Pair(1920, 1080)
        else     -> Pair(1080, 1920)
    }
}
