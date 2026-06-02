package kr.parksy.audio_tools

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "kr.parksy.audio_tools/capture"
        private const val REQUEST_MEDIA_PROJECTION = 1001
        private const val REQUEST_OVERLAY_PERMISSION = 1002
    }

    private var pendingResult: MethodChannel.Result? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    if (hasOverlayPermission()) {
                        result.success(true)
                    } else {
                        pendingResult = result
                        requestOverlayPermission()
                    }
                }
                "startCapture" -> {
                    val presetSec = call.argument<Int>("presetSeconds") ?: 60
                    startCaptureFlow(presetSec, result)
                }
                "stopCapture" -> {
                    AudioCaptureService.instance?.stopRecording()
                    result.success(true)
                }
                "isRecording" -> {
                    result.success(AudioCaptureService.isRecording)
                }
                "getRecordingPath" -> {
                    result.success(AudioCaptureService.lastRecordingPath)
                }
                "hideOverlay" -> {
                    sendServiceCommand(AudioCaptureService.ACTION_HIDE)
                    result.success(true)
                }
                "showOverlay" -> {
                    sendServiceCommand(AudioCaptureService.ACTION_SHOW)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
        }
    }

    private fun startCaptureFlow(presetSec: Int, result: MethodChannel.Result) {
        if (!hasOverlayPermission()) {
            result.error("NO_OVERLAY", "Overlay permission required", null)
            return
        }

        pendingResult = result
        AudioCaptureService.pendingPresetSeconds = presetSec

        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(
            projectionManager.createScreenCaptureIntent(),
            REQUEST_MEDIA_PROJECTION
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_MEDIA_PROJECTION -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    Log.i(TAG, "MediaProjection permission granted")
                    startAudioCaptureService(resultCode, data)
                    pendingResult?.success(true)
                } else {
                    Log.w(TAG, "MediaProjection permission denied")
                    pendingResult?.error("DENIED", "Permission denied", null)
                }
                pendingResult = null
            }
            REQUEST_OVERLAY_PERMISSION -> {
                pendingResult?.success(hasOverlayPermission())
                pendingResult = null
            }
        }
    }

    private fun startAudioCaptureService(resultCode: Int, data: Intent) {
        val serviceIntent = Intent(this, AudioCaptureService::class.java).apply {
            action = AudioCaptureService.ACTION_START
            putExtra(AudioCaptureService.EXTRA_RESULT_CODE, resultCode)
            putExtra(AudioCaptureService.EXTRA_DATA, data)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun sendServiceCommand(action: String) {
        val intent = Intent(this, AudioCaptureService::class.java).apply {
            this.action = action
        }
        startService(intent)
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
