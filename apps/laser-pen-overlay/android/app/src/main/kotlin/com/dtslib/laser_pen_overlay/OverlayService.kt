package com.dtslib.laser_pen_overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Display
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat

/**
 * v19: 화면 녹화 시 컨트롤바 자동 숨김
 *
 * 핵심 원리:
 * - S Pen → 캔버스에 그리기
 * - 손가락 → TouchInjectionService로 아래 앱에 주입
 * - 화면 녹화 감지 → 컨트롤바 숨김
 */
class OverlayService : Service() {

    companion object {
        const val TAG = "OverlayService"
        const val CHANNEL_ID = "laser_pen_overlay"
        const val NOTIFICATION_ID = 1001

        const val ACTION_SHOW = "com.dtslib.laser_pen_overlay.SHOW"
        const val ACTION_HIDE = "com.dtslib.laser_pen_overlay.HIDE"
        const val ACTION_TOGGLE = "com.dtslib.laser_pen_overlay.TOGGLE"
        const val ACTION_CLEAR = "com.dtslib.laser_pen_overlay.CLEAR"
        const val ACTION_COLOR = "com.dtslib.laser_pen_overlay.COLOR"
        const val ACTION_UNDO = "com.dtslib.laser_pen_overlay.UNDO"
        const val ACTION_REDO = "com.dtslib.laser_pen_overlay.REDO"
        const val ACTION_STOP = "com.dtslib.laser_pen_overlay.STOP"

        var instance: OverlayService? = null
        var isOverlayVisible = false

        val COLORS = listOf(Color.WHITE, Color.YELLOW, Color.BLACK, Color.RED, Color.CYAN)
        val COLOR_NAMES = listOf("⚪", "🟡", "⚫", "🔴", "🔵")
    }

    private var windowManager: WindowManager? = null
    private var displayManager: DisplayManager? = null
    private var overlayView: OverlayCanvasView? = null
    private var controlBar: FloatingControlBar? = null
    private var currentColorIndex = 0

    private var canvasParams: WindowManager.LayoutParams? = null
    private var barParams: WindowManager.LayoutParams? = null

    private val handler = Handler(Looper.getMainLooper())

    // 현재 입력 모드 (알림 표시용)
    @Volatile private var currentInputIsStylus = false

    // 화면 녹화 감지
    @Volatile private var isRecording = false
    private var controlBarWasVisible = true

    // 화면 녹화 감지 리스너
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {
            checkForScreenRecording()
        }

        override fun onDisplayRemoved(displayId: Int) {
            checkForScreenRecording()
        }

        override fun onDisplayChanged(displayId: Int) {
            checkForScreenRecording()
        }
    }

    // 주기적 녹화 체크 (백업용)
    private val recordingCheckRunnable = object : Runnable {
        override fun run() {
            checkForScreenRecording()
            handler.postDelayed(this, 1000) // 1초마다 체크
        }
    }

    private fun Int.dp(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, this.toFloat(), resources.displayMetrics
    ).toInt()

    private fun log(msg: String) {
        Log.i(TAG, msg)
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        createNotificationChannel()

        // 화면 녹화 감지 리스너 등록
        displayManager?.registerDisplayListener(displayListener, handler)
        handler.post(recordingCheckRunnable)

        log("서비스 생성 - Accessibility 모드 + 녹화 감지")
    }

    /**
     * 화면 녹화 감지
     * - 가상 디스플레이 존재 여부 확인
     * - 삼성 스크린 레코더 실행 여부 확인
     */
    private fun checkForScreenRecording() {
        val wasRecording = isRecording
        isRecording = isScreenRecordingActive()

        if (isRecording != wasRecording) {
            handler.post {
                if (isRecording) {
                    log("🔴 화면 녹화 감지 - 컨트롤바 숨김")
                    hideControlBar()
                } else {
                    log("⚪ 화면 녹화 종료 - 컨트롤바 표시")
                    showControlBar()
                }
            }
        }
    }

    private fun isScreenRecordingActive(): Boolean {
        // 방법 1: 가상 디스플레이 체크 (화면 녹화는 가상 디스플레이 생성)
        displayManager?.displays?.forEach { display ->
            // 가상 디스플레이 플래그 체크
            if (display.displayId != Display.DEFAULT_DISPLAY) {
                val flags = display.flags
                // FLAG_PRIVATE (1 << 2) = 4, FLAG_PRESENTATION (1 << 1) = 2
                if ((flags and Display.FLAG_PRIVATE) != 0 ||
                    display.name?.contains("recording", ignoreCase = true) == true ||
                    display.name?.contains("Virtual", ignoreCase = true) == true) {
                    return true
                }
            }
        }

        // 방법 2: 삼성 스크린 레코더 앱 실행 체크
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val runningApps = am.runningAppProcesses ?: return false
            for (processInfo in runningApps) {
                if (processInfo.processName.contains("screenrecorder", ignoreCase = true) ||
                    processInfo.processName.contains("screen.recorder", ignoreCase = true)) {
                    return true
                }
            }
        } catch (e: Exception) {
            log("녹화 앱 체크 실패: ${e.message}")
        }

        return false
    }

    private fun hideControlBar() {
        controlBar?.let {
            if (it.visibility == View.VISIBLE) {
                controlBarWasVisible = true
                it.visibility = View.GONE
            }
        }
    }

    private fun showControlBar() {
        controlBar?.let {
            if (controlBarWasVisible && it.visibility == View.GONE) {
                it.visibility = View.VISIBLE
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> { showOverlay(); updateNotification() }
            ACTION_HIDE -> { hideOverlay(); updateNotification() }
            ACTION_TOGGLE -> { if (isOverlayVisible) hideOverlay() else showOverlay(); updateNotification() }
            ACTION_CLEAR -> overlayView?.clear()
            ACTION_COLOR -> { cycleColor(); updateNotification() }
            ACTION_UNDO -> overlayView?.undo()
            ACTION_REDO -> overlayView?.redo()
            ACTION_STOP -> { hideOverlay(); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
            else -> {
                if (Build.VERSION.SDK_INT >= 35) showOverlay()
                startForeground(NOTIFICATION_ID, createNotification())
                if (Build.VERSION.SDK_INT < 35) showOverlay()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        // 화면 녹화 감지 해제
        displayManager?.unregisterDisplayListener(displayListener)
        handler.removeCallbacks(recordingCheckRunnable)

        hideOverlay()
        instance = null
        super.onDestroy()
    }

    private fun showOverlay() {
        if (overlayView != null) return

        // Accessibility Service 체크
        if (!TouchInjectionService.isRunning()) {
            log("⚠️ TouchInjectionService 미실행 - 손가락 터치 주입 불가")
        } else {
            log("✅ TouchInjectionService 활성화됨")
        }

        log("오버레이 표시")

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_PHONE

        // 캔버스: FLAG_NOT_TOUCHABLE 없음! 모든 터치 수신
        canvasParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            // FLAG_NOT_TOUCHABLE 제거됨!
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START }

        overlayView = OverlayCanvasView(this) { isStylus ->
            currentInputIsStylus = isStylus
            log(if (isStylus) "✏️ S Pen 입력" else "👆 손가락 입력")
            updateNotification()
        }
        overlayView?.setStrokeColor(COLORS[currentColorIndex])

        windowManager?.addView(overlayView, canvasParams)
        log("캔버스 추가 (모든 터치 수신)")

        // 컨트롤 바
        barParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = 16.dp()
        }

        controlBar = FloatingControlBar(
            context = this,
            onColorClick = { cycleColor(); updateNotification() },
            onUndoClick = { overlayView?.undo() },
            onRedoClick = { overlayView?.redo() },
            onClearClick = { overlayView?.clear() },
            onCloseClick = { closeOverlay() },
            onDrag = { dx, dy -> moveControlBar(dx, dy) }
        )
        controlBar?.setColorIndex(currentColorIndex)
        windowManager?.addView(controlBar, barParams)

        isOverlayVisible = true
    }

    private fun moveControlBar(dx: Int, dy: Int) {
        barParams?.let { params ->
            params.x += dx
            params.y -= dy
            try { windowManager?.updateViewLayout(controlBar, params) } catch (_: Exception) {}
        }
    }

    private fun hideOverlay() {
        try { overlayView?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        try { controlBar?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        overlayView = null
        controlBar = null
        canvasParams = null
        barParams = null
        isOverlayVisible = false
    }

    fun closeOverlay() {
        hideOverlay()
        updateNotification()
    }

    private fun cycleColor() {
        currentColorIndex = (currentColorIndex + 1) % COLORS.size
        overlayView?.setStrokeColor(COLORS[currentColorIndex])
        controlBar?.setColorIndex(currentColorIndex)
    }

    private fun updateNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, createNotification())
    }

    fun clearCanvas() = overlayView?.clear()
    fun setColor(color: Int) {
        overlayView?.setStrokeColor(color)
        COLORS.indexOf(color).takeIf { it >= 0 }?.let {
            currentColorIndex = it
            controlBar?.setColorIndex(it)
        }
    }
    fun undo() = overlayView?.undo()
    fun redo() = overlayView?.redo()

    /**
     * 터치 통과 모드 설정
     * true: FLAG_NOT_TOUCHABLE 추가 (손가락 터치 통과)
     * false: FLAG_NOT_TOUCHABLE 제거 (터치 수신)
     */
    fun setPassthroughMode(enabled: Boolean) {
        canvasParams?.let { params ->
            if (enabled) {
                params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                log("🔓 패스스루 모드 ON")
            } else {
                params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
                log("🔒 패스스루 모드 OFF")
            }
            try {
                windowManager?.updateViewLayout(overlayView, params)
            } catch (e: Exception) {
                log("패스스루 모드 변경 실패: ${e.message}")
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Laser Pen", NotificationManager.IMPORTANCE_LOW)
            channel.description = "S Pen 오버레이"
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val mainPending = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)

        val accessibilityStatus = if (TouchInjectionService.isRunning()) "✅" else "⚠️"
        val inputMode = if (currentInputIsStylus) "✏️" else "👆"
        val colorEmoji = COLOR_NAMES[currentColorIndex]

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Laser Pen $accessibilityStatus")
            .setContentText("$inputMode | $colorEmoji | ${if (isOverlayVisible) "ON" else "OFF"}")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentIntent(mainPending)
            .addAction(0, if (isOverlayVisible) "OFF" else "ON",
                PendingIntent.getService(this, 1,
                    Intent(this, OverlayService::class.java).apply { action = ACTION_TOGGLE },
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
            .addAction(0, "❌",
                PendingIntent.getService(this, 4,
                    Intent(this, OverlayService::class.java).apply { action = ACTION_STOP },
                    PendingIntent.FLAG_IMMUTABLE))
            .setOngoing(true)
            .build()
    }
}
