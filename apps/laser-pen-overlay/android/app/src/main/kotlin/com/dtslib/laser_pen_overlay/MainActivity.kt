package com.dtslib.laser_pen_overlay

import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dtslib.laser_pen_overlay/touch"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
    }

    override fun dispatchTouchEvent(event: MotionEvent?): Boolean {
        if (event == null) return super.dispatchTouchEvent(event)
        
        val toolType = event.getToolType(0)
        
        // S Pen (STYLUS) 입력만 Flutter로 전달
        // FINGER 입력은 하위 앱으로 pass-through (오버레이 모드에서)
        return when (toolType) {
            MotionEvent.TOOL_TYPE_STYLUS,
            MotionEvent.TOOL_TYPE_ERASER -> {
                // Stylus/Eraser 입력 -> Flutter로 전달
                sendTouchToFlutter(event)
                super.dispatchTouchEvent(event)
            }
            MotionEvent.TOOL_TYPE_FINGER -> {
                // 손가락 입력 -> 현재는 Flutter로 전달 (오버레이 모드에서 pass-through 처리)
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
