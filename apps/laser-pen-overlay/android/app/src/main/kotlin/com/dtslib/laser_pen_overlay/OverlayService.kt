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
import android.os.IBinder
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import androidx.core.app.NotificationCompat

/**
 * 오버레이 서비스 (단순화된 버전)
 *
 * 핵심 변경:
 * - HoverSensorView 제거 (단일 레이어로 통합)
 * - OverlayCanvasView가 직접 호버/터치 처리
 * - FLAG_NOT_TOUCHABLE 동적 토글로 S Pen/손가락 분리
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

    @Volatile
    private var isTouchEnabled = false

    private fun Int.dp(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, this.toFloat(), resources.displayMetrics
    ).toInt()

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        Log.i(TAG, "=== OverlayService 생성됨 ===")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand: action=${intent?.action}")

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
                Log.i(TAG, "ACTION_STOP - 서비스 종료")
                hideOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> {
                // 서비스 시작
                Log.i(TAG, "서비스 시작 (Android SDK: ${Build.VERSION.SDK_INT})")

                // Android 15+: 오버레이를 먼저 표시해야 함
                if (Build.VERSION.SDK_INT >= 35) {
                    Log.i(TAG, "Android 15+: 오버레이 먼저 표시")
                    showOverlay()
                }

                startForeground(NOTIFICATION_ID, createNotification())

                // Android 14 이하: 포그라운드 시작 후 오버레이
                if (Build.VERSION.SDK_INT < 35) {
                    showOverlay()
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.i(TAG, "=== OverlayService 소멸됨 ===")
        hideOverlay()
        instance = null
        super.onDestroy()
    }

    private var hoverSensor: HoverSensorView? = null
    private var sensorParams: WindowManager.LayoutParams? = null

    private fun showOverlay() {
        if (overlayView != null) {
            Log.w(TAG, "오버레이 이미 표시 중")
            return
        }

        Log.i(TAG, ">>> 오버레이 표시 시작")

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // 1. 캔버스 레이어 (하단) - 기본 터치 비활성
        canvasParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        overlayView = OverlayCanvasView(
            context = this,
            onStylusStateChanged = { /* 센서에서 처리 */ }
        )
        overlayView?.setStrokeColor(COLORS[currentColorIndex])

        try {
            windowManager?.addView(overlayView, canvasParams)
            Log.i(TAG, "캔버스 뷰 추가됨")
        } catch (e: Exception) {
            Log.e(TAG, "캔버스 뷰 추가 실패: ${e.message}")
            return
        }

        // 2. 호버 센서 레이어 (상단) - FLAG_NOT_TOUCHABLE 없음! 호버 감지용
        sensorParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        hoverSensor = HoverSensorView(
            context = this,
            onStylusNear = {
                Log.i(TAG, ">>> 센서: S Pen 감지! 터치 모드 활성화")
                enableTouchMode()
                enableSensorPassThrough()
            },
            onStylusAway = {
                Log.i(TAG, ">>> 센서: S Pen 떠남! 터치 모드 비활성화")
                disableTouchMode()
            },
            onFingerDetected = {
                Log.i(TAG, ">>> 센서: 손가락 감지! 센서 패스스루")
                enableSensorPassThrough()
            }
        )

        try {
            windowManager?.addView(hoverSensor, sensorParams)
            Log.i(TAG, "호버 센서 추가됨")
        } catch (e: Exception) {
            Log.e(TAG, "호버 센서 추가 실패: ${e.message}")
        }

        isTouchEnabled = false

        // 컨트롤 바
        barParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_SECURE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = 16.dp()
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
                Log.i(TAG, "닫기 버튼 클릭")
                closeOverlay()
            },
            onDrag = { deltaX, deltaY ->
                updateControlBarPosition(deltaX, deltaY)
            }
        )
        controlBar?.setColorIndex(currentColorIndex)

        try {
            windowManager?.addView(controlBar, barParams)
            Log.i(TAG, "컨트롤 바 추가됨")
        } catch (e: Exception) {
            Log.e(TAG, "컨트롤 바 추가 실패: ${e.message}")
        }

        isOverlayVisible = true
        Log.i(TAG, ">>> 오버레이 표시 완료 (터치 비활성 상태)")
    }

    /**
     * S Pen 감지 → 터치 모드 활성화
     */
    private fun enableTouchMode() {
        if (isTouchEnabled) {
            Log.d(TAG, "터치 모드 이미 활성")
            return
        }

        Log.i(TAG, ">>> 터치 모드 활성화 (S Pen 그리기 가능)")

        canvasParams?.let { params ->
            // FLAG_NOT_TOUCHABLE 제거
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
            try {
                windowManager?.updateViewLayout(overlayView, params)
                isTouchEnabled = true
                Log.i(TAG, "플래그 업데이트 완료: 터치 활성")
            } catch (e: Exception) {
                Log.e(TAG, "터치 모드 활성화 실패: ${e.message}")
            }
        }
    }

    /**
     * S Pen 떠남 → 터치 모드 비활성화 (손가락 터치 통과)
     */
    private fun disableTouchMode() {
        if (!isTouchEnabled) {
            Log.d(TAG, "터치 모드 이미 비활성")
            return
        }

        Log.i(TAG, ">>> 터치 모드 비활성화 (손가락 터치 통과)")

        canvasParams?.let { params ->
            // FLAG_NOT_TOUCHABLE 추가
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            try {
                windowManager?.updateViewLayout(overlayView, params)
                isTouchEnabled = false
                overlayView?.resetStylusState()
                Log.i(TAG, "플래그 업데이트 완료: 터치 비활성")
            } catch (e: Exception) {
                Log.e(TAG, "터치 모드 비활성화 실패: ${e.message}")
            }
        }

        // 센서도 다시 터치 가능하게 (호버 감지용)
        disableSensorPassThrough()
    }

    /**
     * 센서 레이어 터치 통과 활성화 (손가락 터치가 아래로 가도록)
     */
    private fun enableSensorPassThrough() {
        sensorParams?.let { params ->
            if ((params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE) == 0) {
                params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                try {
                    windowManager?.updateViewLayout(hoverSensor, params)
                    Log.i(TAG, "센서 패스스루 활성화")
                } catch (e: Exception) {
                    Log.e(TAG, "센서 패스스루 활성화 실패: ${e.message}")
                }
            }
        }
    }

    /**
     * 센서 레이어 터치 통과 비활성화 (호버 감지 모드로 복귀)
     */
    private fun disableSensorPassThrough() {
        sensorParams?.let { params ->
            if ((params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE) != 0) {
                params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
                try {
                    windowManager?.updateViewLayout(hoverSensor, params)
                    Log.i(TAG, "센서 호버 감지 모드 복귀")
                } catch (e: Exception) {
                    Log.e(TAG, "센서 모드 변경 실패: ${e.message}")
                }
            }
        }
    }

    private fun updateControlBarPosition(deltaX: Int, deltaY: Int) {
        barParams?.let { params ->
            params.x += deltaX
            params.y -= deltaY
            try {
                windowManager?.updateViewLayout(controlBar, params)
            } catch (e: Exception) {
                Log.e(TAG, "컨트롤 바 위치 업데이트 실패: ${e.message}")
            }
        }
    }

    private fun hideOverlay() {
        Log.i(TAG, ">>> 오버레이 숨김")

        try {
            overlayView?.let {
                windowManager?.removeView(it)
                overlayView = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "캔버스 제거 실패: ${e.message}")
        }

        try {
            hoverSensor?.let {
                windowManager?.removeView(it)
                hoverSensor = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "센서 제거 실패: ${e.message}")
        }

        try {
            controlBar?.let {
                windowManager?.removeView(it)
                controlBar = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "컨트롤 바 제거 실패: ${e.message}")
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
                description = "S Pen 오버레이 판서 서비스"
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

        val toggleIntent = Intent(this, OverlayService::class.java).apply { action = ACTION_TOGGLE }
        val togglePendingIntent = PendingIntent.getService(
            this, 1, toggleIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val colorIntent = Intent(this, OverlayService::class.java).apply { action = ACTION_COLOR }
        val colorPendingIntent = PendingIntent.getService(
            this, 2, colorIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val clearIntent = Intent(this, OverlayService::class.java).apply { action = ACTION_CLEAR }
        val clearPendingIntent = PendingIntent.getService(
            this, 3, clearIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, OverlayService::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getService(
            this, 4, stopIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val statusEmoji = if (isOverlayVisible) "🖊️" else "⏸️"
        val colorEmoji = COLOR_NAMES[currentColorIndex]
        val toggleText = if (isOverlayVisible) "OFF" else "ON"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Laser Pen")
            .setContentText("$statusEmoji $colorEmoji | S Pen=그리기, 손가락=터치통과")
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
