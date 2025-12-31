package com.dtslib.parksy_glot

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val AUDIO_CHANNEL = "com.dtslib.parksy_glot/audio"
    private val OVERLAY_CHANNEL = "com.dtslib.parksy_glot/overlay"

    private val MEDIA_PROJECTION_REQUEST_CODE = 1001
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1002

    private var pendingResult: MethodChannel.Result? = null
    private var mediaProjectionManager: MediaProjectionManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        // Audio capture channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                }
                "requestPermissions" -> {
                    result.success(true) // Audio capture doesn't need runtime permissions
                }
                "createMediaProjection" -> {
                    pendingResult = result
                    val intent = mediaProjectionManager?.createScreenCaptureIntent()
                    startActivityForResult(intent, MEDIA_PROJECTION_REQUEST_CODE)
                }
                "startCapture" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    val channelCount = call.argument<Int>("channelCount") ?: 1
                    val started = AudioCaptureService.startCapture(this, sampleRate, channelCount)
                    result.success(started)
                }
                "stopCapture" -> {
                    AudioCaptureService.stopCapture()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Overlay channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        pendingResult = result
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                    } else {
                        result.success(true)
                    }
                }
                "startOverlayService" -> {
                    val intent = Intent(this, SubtitleOverlayService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopOverlayService" -> {
                    val intent = Intent(this, SubtitleOverlayService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "showOverlay" -> {
                    SubtitleOverlayService.showOverlay()
                    result.success(true)
                }
                "hideOverlay" -> {
                    SubtitleOverlayService.hideOverlay()
                    result.success(true)
                }
                "isOverlayVisible" -> {
                    result.success(SubtitleOverlayService.isVisible())
                }
                "updateSubtitle" -> {
                    val korean = call.argument<String>("korean") ?: ""
                    val english = call.argument<String>("english") ?: ""
                    val original = call.argument<String>("original") ?: ""
                    val showOriginal = call.argument<Boolean>("showOriginal") ?: false
                    SubtitleOverlayService.updateSubtitle(korean, english, original, showOriginal)
                    result.success(true)
                }
                "setFontSize" -> {
                    val scale = call.argument<Double>("scale") ?: 1.0
                    SubtitleOverlayService.setFontScale(scale.toFloat())
                    result.success(true)
                }
                "toggleOriginal" -> {
                    val show = call.argument<Boolean>("show") ?: false
                    SubtitleOverlayService.toggleOriginal(show)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            MEDIA_PROJECTION_REQUEST_CODE -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    AudioCaptureService.setMediaProjectionData(resultCode, data)
                    pendingResult?.success(true)
                } else {
                    pendingResult?.success(false)
                }
                pendingResult = null
            }
            OVERLAY_PERMISSION_REQUEST_CODE -> {
                pendingResult?.success(Settings.canDrawOverlays(this))
                pendingResult = null
            }
        }
    }
}
