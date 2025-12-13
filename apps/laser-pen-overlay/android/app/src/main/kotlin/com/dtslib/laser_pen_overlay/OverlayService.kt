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
    private var controlBar: FloatingControlBar? = null
    private var currentColorIndex = 0
    
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
        
        // Canvas overlay: 터치 통과 가능하게 설정
        // FLAG_NOT_TOUCHABLE 제거 → View.dispatchTouchEvent에서 분기
        val canvasParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        
        overlayView = OverlayCanvasView(this)
        overlayView?.setStrokeColor(COLORS[currentColorIndex])
        windowManager?.addView(overlayView, canvasParams)
        
        // Control bar: 항상 터치 가능 (focusable 아님, 하지만 clickable)
        val barParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = 60.dp()
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
            }
        )
        controlBar?.setColorIndex(currentColorIndex)
        windowManager?.addView(controlBar, barParams)
        
        isOverlayVisible = true
        Log.d(TAG, "Overlay shown successfully")
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
            controlBar?.let {
                windowManager?.removeView(it)
                controlBar = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing controlBar: ${e.message}")
        }
        
        isOverlayVisible = false
    }
    
    /**
     * Exit 버튼용: 오버레이만 닫고 서비스는 유지
     */
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
