package com.dtslib.laser_pen_overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import androidx.core.app.NotificationCompat

/**
 * 완전 재설계된 오버레이 서비스
 *
 * 핵심 원리:
 * - S Pen은 항상 호버 → 터치 순서 (디지타이저 특성)
 * - 호버 감지로 FLAG_NOT_TOUCHABLE 토글
 * - 호버 감지 실패 대비: 터치에서도 stylus 체크
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
    private var overlayView: OverlayCanvasView? = null
    private var controlBar: FloatingControlBar? = null
    private var currentColorIndex = 0

    private var canvasParams: WindowManager.LayoutParams? = null
    private var barParams: WindowManager.LayoutParams? = null

    private val handler = Handler(Looper.getMainLooper())

    // S Pen 상태
    @Volatile private var isStylusMode = false
    private val stylusTimeout = Runnable {
        log("S Pen 타임아웃 → 손가락 모드")
        setStylusMode(false)
    }

    private fun Int.dp(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, this.toFloat(), resources.displayMetrics
    ).toInt()

    private fun log(msg: String) {
        Log.i(TAG, msg)
        // Toast로도 표시 (디버깅용)
        // handler.post { Toast.makeText(this, msg, Toast.LENGTH_SHORT).show() }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        log("서비스 생성")
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
        hideOverlay()
        instance = null
        super.onDestroy()
    }

    private fun showOverlay() {
        if (overlayView != null) return
        log("오버레이 표시")

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_PHONE

        // 캔버스: 기본적으로 터치 비활성 (손가락 통과)
        canvasParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,  // 기본: 터치 통과
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START }

        overlayView = OverlayCanvasView(this) { /* unused */ }
        overlayView?.setStrokeColor(COLORS[currentColorIndex])

        // 호버 리스너 설정 (FLAG_NOT_TOUCHABLE이어도 호버는 받음)
        overlayView?.setOnHoverListener { _, event ->
            handleHoverEvent(event)
        }

        windowManager?.addView(overlayView, canvasParams)
        log("캔버스 추가 (터치 비활성)")

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

    /**
     * 호버 이벤트 처리 - S Pen 감지의 핵심!
     */
    private fun handleHoverEvent(event: MotionEvent): Boolean {
        val isStylus = isStylus(event)

        when (event.actionMasked) {
            MotionEvent.ACTION_HOVER_ENTER -> {
                if (isStylus) {
                    log("✏️ S Pen 호버 진입!")
                    setStylusMode(true)
                }
            }
            MotionEvent.ACTION_HOVER_MOVE -> {
                if (isStylus && !isStylusMode) {
                    log("✏️ S Pen 호버 이동 (재감지)")
                    setStylusMode(true)
                }
                resetStylusTimeout()
            }
            MotionEvent.ACTION_HOVER_EXIT -> {
                if (isStylus) {
                    log("✏️ S Pen 호버 퇴장")
                    startStylusTimeout()
                }
            }
        }
        return isStylus
    }

    private fun isStylus(event: MotionEvent): Boolean {
        for (i in 0 until event.pointerCount) {
            val toolType = event.getToolType(i)
            if (toolType == MotionEvent.TOOL_TYPE_STYLUS ||
                toolType == MotionEvent.TOOL_TYPE_ERASER) {
                return true
            }
        }
        return false
    }

    /**
     * S Pen 모드 전환
     */
    private fun setStylusMode(enabled: Boolean) {
        if (isStylusMode == enabled) return
        isStylusMode = enabled

        canvasParams?.let { params ->
            if (enabled) {
                // S Pen 모드: 터치 활성화
                params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
                log("🖊️ 터치 활성화 (S Pen 그리기 가능)")
            } else {
                // 손가락 모드: 터치 비활성화 (통과)
                params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                log("👆 터치 비활성화 (손가락 통과)")
            }
            try {
                windowManager?.updateViewLayout(overlayView, params)
                updateNotification()
            } catch (e: Exception) {
                log("플래그 변경 실패: ${e.message}")
            }
        }
    }

    private fun resetStylusTimeout() {
        handler.removeCallbacks(stylusTimeout)
        handler.postDelayed(stylusTimeout, 500)
    }

    private fun startStylusTimeout() {
        handler.removeCallbacks(stylusTimeout)
        handler.postDelayed(stylusTimeout, 500)
    }

    private fun moveControlBar(dx: Int, dy: Int) {
        barParams?.let { params ->
            params.x += dx
            params.y -= dy
            try { windowManager?.updateViewLayout(controlBar, params) } catch (_: Exception) {}
        }
    }

    private fun hideOverlay() {
        handler.removeCallbacks(stylusTimeout)
        try { overlayView?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        try { controlBar?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        overlayView = null
        controlBar = null
        canvasParams = null
        barParams = null
        isStylusMode = false
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

        val modeText = if (isStylusMode) "🖊️ S Pen" else "👆 손가락통과"
        val colorEmoji = COLOR_NAMES[currentColorIndex]

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Laser Pen")
            .setContentText("$modeText | $colorEmoji")
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
