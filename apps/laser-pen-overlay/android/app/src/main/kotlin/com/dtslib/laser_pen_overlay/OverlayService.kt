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
import android.view.WindowManager
import android.widget.Toast
import androidx.core.app.NotificationCompat

/**
 * v14: 주기적 Peek 방식 S Pen 감지
 *
 * 핵심 원리:
 * - 기본: FLAG_NOT_TOUCHABLE (손가락 터치 통과)
 * - 100ms마다 10ms간 FLAG 해제하여 S Pen 호버 감지
 * - S Pen 감지 시 FLAG 해제 유지 → 그리기 가능
 * - S Pen 떠나면 FLAG 복원 → 손가락 통과
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
    @Volatile private var isPeeking = false

    // Peek 타이머 (S Pen 감지용)
    private val peekRunnable = object : Runnable {
        override fun run() {
            if (!isStylusMode && !isPeeking && overlayView != null) {
                startPeek()
            }
            handler.postDelayed(this, 100) // 100ms마다 peek
        }
    }

    // Peek 종료 타이머
    private val peekEndRunnable = Runnable {
        if (!isStylusMode) {
            endPeek()
        }
        isPeeking = false
    }

    // S Pen 타임아웃
    private val stylusTimeout = Runnable {
        log("S Pen 타임아웃 → 손가락 모드")
        setStylusMode(false)
    }

    private fun Int.dp(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, this.toFloat(), resources.displayMetrics
    ).toInt()

    private fun log(msg: String) {
        Log.i(TAG, msg)
    }

    private fun toast(msg: String) {
        handler.post { Toast.makeText(this, msg, Toast.LENGTH_SHORT).show() }
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

        // 캔버스: 기본 FLAG_NOT_TOUCHABLE (손가락 통과)
        canvasParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START }

        // OverlayCanvasView 콜백 연결
        overlayView = OverlayCanvasView(this) { stylusNear ->
            if (stylusNear) {
                log("Canvas: S Pen 감지!")
                toast("🖊️ S Pen!")
                setStylusMode(true)
            } else {
                log("Canvas: S Pen 떠남")
                setStylusMode(false)
            }
        }
        overlayView?.setStrokeColor(COLORS[currentColorIndex])

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

        // Peek 타이머 시작
        handler.postDelayed(peekRunnable, 500)
        log("Peek 타이머 시작")
    }

    /**
     * Peek 시작: 잠깐 FLAG_NOT_TOUCHABLE 해제하여 호버 감지
     */
    private fun startPeek() {
        isPeeking = true
        canvasParams?.let { params ->
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
            try {
                windowManager?.updateViewLayout(overlayView, params)
            } catch (e: Exception) {
                log("Peek 시작 실패: ${e.message}")
            }
        }
        // 15ms 후 peek 종료
        handler.postDelayed(peekEndRunnable, 15)
    }

    /**
     * Peek 종료: FLAG_NOT_TOUCHABLE 복원
     */
    private fun endPeek() {
        canvasParams?.let { params ->
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            try {
                windowManager?.updateViewLayout(overlayView, params)
            } catch (e: Exception) {
                log("Peek 종료 실패: ${e.message}")
            }
        }
    }

    /**
     * S Pen 모드 전환
     */
    private fun setStylusMode(enabled: Boolean) {
        if (isStylusMode == enabled) return
        isStylusMode = enabled

        handler.removeCallbacks(stylusTimeout)

        canvasParams?.let { params ->
            if (enabled) {
                // S Pen 모드: 터치 활성화
                params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
                log("🖊️ S Pen 모드 ON - 그리기 가능")
            } else {
                // 손가락 모드: 터치 비활성화 (통과)
                params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                log("👆 손가락 모드 - 터치 통과")
            }
            try {
                windowManager?.updateViewLayout(overlayView, params)
                updateNotification()
            } catch (e: Exception) {
                log("플래그 변경 실패: ${e.message}")
            }
        }

        if (enabled) {
            // S Pen 타임아웃 시작 (500ms 후 손가락 모드로)
            handler.postDelayed(stylusTimeout, 500)
        }
    }

    private fun moveControlBar(dx: Int, dy: Int) {
        barParams?.let { params ->
            params.x += dx
            params.y -= dy
            try { windowManager?.updateViewLayout(controlBar, params) } catch (_: Exception) {}
        }
    }

    private fun hideOverlay() {
        handler.removeCallbacks(peekRunnable)
        handler.removeCallbacks(peekEndRunnable)
        handler.removeCallbacks(stylusTimeout)
        try { overlayView?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        try { controlBar?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        overlayView = null
        controlBar = null
        canvasParams = null
        barParams = null
        isStylusMode = false
        isPeeking = false
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
