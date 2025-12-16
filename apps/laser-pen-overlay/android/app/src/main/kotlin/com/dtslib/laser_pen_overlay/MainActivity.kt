package com.dtslib.laser_pen_overlay

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.MotionEvent
import android.view.accessibility.AccessibilityManager
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
        private const val REQUEST_ACCESSIBILITY_PERMISSION = 1002
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkAndRequestPermissions()
    }

    override fun onResume() {
        super.onResume()
        // 설정에서 돌아올 때 권한 다시 체크
        updatePermissionStatus()
    }

    private fun checkAndRequestPermissions() {
        when {
            !checkOverlayPermission() -> {
                requestOverlayPermission()
            }
            !isAccessibilityServiceEnabled() -> {
                showAccessibilityPrompt()
            }
            else -> {
                startOverlayServiceAndShow()
            }
        }
    }

    private fun updatePermissionStatus() {
        val overlayOk = checkOverlayPermission()
        val accessibilityOk = isAccessibilityServiceEnabled()

        if (overlayOk && accessibilityOk) {
            // 모든 권한 OK - 서비스 시작
            if (OverlayService.instance == null) {
                startOverlayServiceAndShow()
            }
        } else if (overlayOk && !accessibilityOk) {
            // 오버레이 OK, 접근성 필요
            Toast.makeText(this, "⚠️ 접근성 권한 필요 - 손가락 스크롤 작동 안 함", Toast.LENGTH_LONG).show()
            // 접근성 없어도 S Pen 그리기는 동작
            startOverlayServiceAndShow()
        }
    }

    // ===== 오버레이 권한 =====

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

    // ===== 접근성 권한 =====

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)

        for (service in enabledServices) {
            val serviceId = service.resolveInfo.serviceInfo
            if (serviceId.packageName == packageName &&
                serviceId.name == TouchInjectionService::class.java.name) {
                return true
            }
        }
        return false
    }

    private fun showAccessibilityPrompt() {
        Toast.makeText(
            this,
            "손가락 터치 전달을 위해 접근성 서비스를 켜주세요\n\n설정 → 접근성 → Laser Pen 터치 전달 → 켜기",
            Toast.LENGTH_LONG
        ).show()

        // 접근성 설정 화면으로 이동
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivityForResult(intent, REQUEST_ACCESSIBILITY_PERMISSION)
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
    }

    // ===== Activity 결과 처리 =====

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_OVERLAY_PERMISSION -> {
                if (checkOverlayPermission()) {
                    // 오버레이 권한 획득, 접근성 체크
                    if (!isAccessibilityServiceEnabled()) {
                        showAccessibilityPrompt()
                    } else {
                        startOverlayServiceAndShow()
                    }
                } else {
                    Toast.makeText(this, "오버레이 권한이 필요합니다", Toast.LENGTH_SHORT).show()
                }
            }
            REQUEST_ACCESSIBILITY_PERMISSION -> {
                if (isAccessibilityServiceEnabled()) {
                    Toast.makeText(this, "✅ 접근성 서비스 활성화됨", Toast.LENGTH_SHORT).show()
                    startOverlayServiceAndShow()
                } else {
                    Toast.makeText(this, "⚠️ 접근성 미활성화 - S Pen만 동작", Toast.LENGTH_LONG).show()
                    // 접근성 없어도 S Pen 그리기는 동작
                    startOverlayServiceAndShow()
                }
            }
        }
    }

    // ===== 서비스 제어 =====

    private fun startOverlayServiceAndShow() {
        startOverlayService()
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
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
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
