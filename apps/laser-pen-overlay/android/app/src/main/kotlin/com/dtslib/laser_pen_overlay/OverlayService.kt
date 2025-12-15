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
import androidx.core.app.NotificationCompat

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

        val COLORS = listOf(
            Color.WHITE,
            Color.YELLOW,
            Color.BLACK,
            Color.RED,
            Color.CYAN
        )
        val COLOR_NAMES = listOf("⚪", "🟡", "⚫", "🔴", "🔵")
    }

    private var windowManager: WindowManager? = null
    private var overlayView: OverlayCanvasView? = null
    private var hoverSensor: HoverSensorView? = null
    private var controlBar: FloatingControlBar? = null
    private var currentColorIndex = 0

    private var canvasParams: WindowManager.LayoutParams? = null
    private var sensorParams: WindowManager.LayoutParams? = null
    private var barParams: WindowManager.LayoutParams? = null
    private var isTouchEnabled = false

    private fun Int.dp(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        this.toFloat(),
        resources.displayMetrics
    ).toInt()

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")

        when (intent?.action) {
            ACTION_SHOW -> {
                showOverlay()
                updateNotification()
            }
            ACTION_HIDE -> {
                hideOverlay()
                updateNotification()
            }
            ACTION_TOGGLE -> {
                if (isOverlayVisible) hideOverlay() else showOverlay()
                updateNotification()
            }
            ACTION_CLEAR -> overlayView?.clear()
            ACTION_COLOR -> {
                cycleColor()
                updateNotification()
            }
            ACTION_UNDO -> overlayView?.undo()
            ACTION_REDO -> overlayView?.redo()
            ACTION_STOP -> {
                Log.d(TAG, "ACTION_STOP received")
                hideOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> startForeground(NOTIFICATION_ID, createNotification())
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "Service destroyed")
        hideOverlay()
        instance = null
        super.onDestroy()
    }

    private fun showOverlay() {
        if (overlayView != null) {
            Log.d(TAG, "Overlay already visible")
            return
        }

        Log.d(TAG, "Showing overlay")

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // Canvas overlay: 기본적으로 터치 통과 (FLAG_NOT_TOUCHABLE)
        // S Pen 호버 감지시 터치 활성화
        canvasParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,  // 기본: 터치 통과
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        overlayView = OverlayCanvasView(
            context = this,
            onStylusNear = { /* 센서에서 처리 */ },
            onStylusAway = { /* 센서에서 처리 */ }
        )
        overlayView?.setStrokeColor(COLORS[currentColorIndex])
        windowManager?.addView(overlayView, canvasParams)
        isTouchEnabled = false

        // Hover Sensor: FLAG_NOT_TOUCHABLE로 설정하여 터치는 절대 받지 않음
        // 중요: FLAG_NOT_TOUCHABLE은 터치만 차단, 호버 이벤트는 여전히 수신 가능!
        // 이렇게 하면 손가락 터치가 센서를 거치지 않고 바로 아래 앱으로 전달됨
        sensorParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,  // 터치 완전 차단 (호버만 감지)
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        hoverSensor = HoverSensorView(
            context = this,
            onStylusNear = { enableTouchMode() },
            onStylusAway = { disableTouchMode() },
            onStylusTouchEvent = { event ->
                // 센서는 FLAG_NOT_TOUCHABLE이므로 터치 이벤트를 받지 않음
                // 이 콜백은 호환성을 위해 유지하지만 실제로는 호출되지 않음
                overlayView?.dispatchTouchEvent(event) ?: false
            },
            onFingerTouchDetected = {
                // 더 이상 필요 없음 - 센서가 터치를 받지 않으므로
            }
        )
        windowManager?.addView(hoverSensor, sensorParams)

        // Control bar: 최하단 배치, 드래그 가능
        // FLAG_SECURE: 화면 녹화/캡처에서 숨김 (삼성 화면녹화처럼 사용자는 보이지만 녹화에는 안 보임)
        barParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_SECURE,  // 화면 녹화에서 숨김
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = 16.dp()  // 최하단에서 약간 위
        }

        controlBar = FloatingControlBar(
            context = this,
            onColorClick = {
                cycleColor()
                updateNotification()
            },
            onUndoClick = { overlayView?.undo() },
            onRedoClick = { overlayView?.redo() },
            onClearClick = { overlayView?.clear() },
            onCloseClick = {
                Log.d(TAG, "Close button clicked")
                closeOverlay()
            },
            onDrag = { deltaX, deltaY ->
                updateControlBarPosition(deltaX, deltaY)
            }
        )
        controlBar?.setColorIndex(currentColorIndex)
        windowManager?.addView(controlBar, barParams)

        isOverlayVisible = true
        Log.d(TAG, "Overlay shown successfully")
    }

    /**
     * S Pen 감지시 터치 모드 활성화
     */
    private fun enableTouchMode() {
        if (isTouchEnabled) return
        Log.d(TAG, "Enabling touch mode for S Pen")

        canvasParams?.let { params ->
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
            try {
                windowManager?.updateViewLayout(overlayView, params)
                isTouchEnabled = true
            } catch (e: Exception) {
                Log.e(TAG, "Error enabling touch mode: ${e.message}")
            }
        }
    }

    /**
     * S Pen 떠남 → 터치 모드 비활성화 (손가락 터치 통과)
     */
    private fun disableTouchMode() {
        if (!isTouchEnabled) return
        Log.d(TAG, "Disabling touch mode - finger can now scroll")

        canvasParams?.let { params ->
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            try {
                windowManager?.updateViewLayout(overlayView, params)
                isTouchEnabled = false
                overlayView?.resetStylusState()
            } catch (e: Exception) {
                Log.e(TAG, "Error disabling touch mode: ${e.message}")
            }
        }
    }

    /**
     * 센서 레이어의 상태 리셋
     */
    fun resetSensorState() {
        hoverSensor?.resetStylusState()
    }

    // 센서는 이제 항상 FLAG_NOT_TOUCHABLE이므로 enable/disable 로직 불필요
    // 호버 이벤트는 FLAG_NOT_TOUCHABLE과 무관하게 수신됨

    /**
     * 컨트롤 바 위치 업데이트 (드래그)
     */
    private fun updateControlBarPosition(deltaX: Int, deltaY: Int) {
        barParams?.let { params ->
            params.x += deltaX
            params.y -= deltaY  // y좌표는 반전 (Gravity.BOTTOM 기준)
            try {
                windowManager?.updateViewLayout(controlBar, params)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating control bar position: ${e.message}")
            }
        }
    }

    private fun hideOverlay() {
        Log.d(TAG, "Hiding overlay")

        try {
            overlayView?.let {
                windowManager?.removeView(it)
                overlayView = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing overlayView: ${e.message}")
        }

        try {
            hoverSensor?.let {
                windowManager?.removeView(it)
                hoverSensor = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing hoverSensor: ${e.message}")
        }

        try {
            controlBar?.let {
                windowManager?.removeView(it)
                controlBar = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing controlBar: ${e.message}")
        }

        canvasParams = null
        sensorParams = null
        barParams = null
        isTouchEnabled = false
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
        val idx = COLORS.indexOf(color)
        if (idx >= 0) {
            currentColorIndex = idx
            controlBar?.setColorIndex(idx)
        }
    }

    fun undo() = overlayView?.undo()
    fun redo() = overlayView?.redo()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Laser Pen Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "오버레이 판서 활성화 중"
                setShowBadge(false)
            }
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val mainIntent = Intent(this, MainActivity::class.java)
        val mainPendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val toggleIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_TOGGLE
        }
        val togglePendingIntent = PendingIntent.getService(
            this, 1, toggleIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val colorIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_COLOR
        }
        val colorPendingIntent = PendingIntent.getService(
            this, 2, colorIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val clearIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_CLEAR
        }
        val clearPendingIntent = PendingIntent.getService(
            this, 3, clearIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 4, stopIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val statusEmoji = if (isOverlayVisible) "🖊️" else "⏸️"
        val colorEmoji = COLOR_NAMES[currentColorIndex]
        val toggleText = if (isOverlayVisible) "OFF" else "ON"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Laser Pen")
            .setContentText("$statusEmoji $colorEmoji")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentIntent(mainPendingIntent)
            .addAction(0, toggleText, togglePendingIntent)
            .addAction(0, colorEmoji, colorPendingIntent)
            .addAction(0, "🧹", clearPendingIntent)
            .addAction(0, "❌", stopPendingIntent)
            .setOngoing(true)
            .build()
    }
}
