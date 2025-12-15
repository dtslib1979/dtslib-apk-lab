package com.dtslib.laser_pen_overlay

import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.MotionEvent
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dtslib.laser_pen_overlay/touch"
    private val OVERLAY_CHANNEL = "com.dtslib.laser_pen_overlay/overlay"
    private var methodChannel: MethodChannel? = null
    private var overlayChannel: MethodChannel? = null

    companion object {
        private const val REQUEST_OVERLAY_PERMISSION = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 앱 시작 시 바로 오버레이 실행
        if (checkOverlayPermission()) {
            startOverlayServiceAndShow()
        } else {
            requestOverlayPermission()
        }
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
            Toast.makeText(this, "오버레이 권한을 허용해주세요", Toast.LENGTH_LONG).show()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_OVERLAY_PERMISSION) {
            if (checkOverlayPermission()) {
                startOverlayServiceAndShow()
            } else {
                Toast.makeText(this, "오버레이 권한이 필요합니다", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun startOverlayServiceAndShow() {
        startOverlayService()
        // 약간의 딜레이 후 오버레이 표시 (서비스 시작 대기)
        window.decorView.postDelayed({
            showOverlay()
        }, 100)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 기존 터치 채널
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInputMode" -> {
                    result.success("stylus_only")
                }
                else -> result.notImplemented()
            }
        }
        
        // 오버레이 서비스 제어 채널
        overlayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OVERLAY_CHANNEL
        )
        
        overlayChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startOverlayService()
                    result.success(true)
                }
                "stopService" -> {
                    stopOverlayService()
                    result.success(true)
                }
                "showOverlay" -> {
                    showOverlay()
                    result.success(true)
                }
                "hideOverlay" -> {
                    hideOverlay()
                    result.success(true)
                }
                "isOverlayVisible" -> {
                    result.success(OverlayService.isOverlayVisible)
                }
                "setColor" -> {
                    val colorName = call.argument<String>("color") ?: "white"
                    val color = when (colorName) {
                        "white" -> Color.WHITE
                        "yellow" -> Color.YELLOW
                        "black" -> Color.BLACK
                        else -> Color.WHITE
                    }
                    OverlayService.instance?.setColor(color)
                    result.success(true)
                }
                "clear" -> {
                    OverlayService.instance?.clearCanvas()
                    result.success(true)
                }
                "undo" -> {
                    OverlayService.instance?.undo()
                    result.success(true)
                }
                "redo" -> {
                    OverlayService.instance?.redo()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startOverlayService() {
        val intent = Intent(this, OverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
    
    private fun stopOverlayService() {
        val intent = Intent(this, OverlayService::class.java).apply {
            action = OverlayService.ACTION_STOP
        }
        startService(intent)
    }
    
    private fun showOverlay() {
        val intent = Intent(this, OverlayService::class.java).apply {
            action = OverlayService.ACTION_SHOW
        }
        startService(intent)
    }
    
    private fun hideOverlay() {
        val intent = Intent(this, OverlayService::class.java).apply {
            action = OverlayService.ACTION_HIDE
        }
        startService(intent)
    }

    override fun dispatchTouchEvent(event: MotionEvent?): Boolean {
        if (event == null) return super.dispatchTouchEvent(event)
        
        val toolType = event.getToolType(0)
        
        return when (toolType) {
            MotionEvent.TOOL_TYPE_STYLUS,
            MotionEvent.TOOL_TYPE_ERASER -> {
                sendTouchToFlutter(event)
                super.dispatchTouchEvent(event)
            }
            MotionEvent.TOOL_TYPE_FINGER -> {
                super.dispatchTouchEvent(event)
            }
            else -> super.dispatchTouchEvent(event)
        }
    }

    private fun sendTouchToFlutter(event: MotionEvent) {
        val action = when (event.action) {
            MotionEvent.ACTION_DOWN -> "down"
            MotionEvent.ACTION_MOVE -> "move"
            MotionEvent.ACTION_UP -> "up"
            MotionEvent.ACTION_CANCEL -> "cancel"
            else -> return
        }
        
        val data = mapOf(
            "action" to action,
            "x" to event.x.toDouble(),
            "y" to event.y.toDouble(),
            "pressure" to event.pressure.toDouble(),
            "toolType" to event.getToolType(0)
        )
        
        methodChannel?.invokeMethod("onStylusTouch", data)
    }
}
