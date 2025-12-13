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
import android.view.Gravity
import android.view.WindowManager
import androidx.core.app.NotificationCompat

class OverlayService : Service() {
    
    companion object {
        const val CHANNEL_ID = "laser_pen_overlay"
        const val NOTIFICATION_ID = 1001
        const val ACTION_SHOW = "com.dtslib.laser_pen_overlay.SHOW"
        const val ACTION_HIDE = "com.dtslib.laser_pen_overlay.HIDE"
        const val ACTION_TOGGLE = "com.dtslib.laser_pen_overlay.TOGGLE"
        const val ACTION_CLEAR = "com.dtslib.laser_pen_overlay.CLEAR"
        const val ACTION_COLOR = "com.dtslib.laser_pen_overlay.COLOR"
        const val ACTION_STOP = "com.dtslib.laser_pen_overlay.STOP"
        
        var instance: OverlayService? = null
        var isOverlayVisible = false
        
        // 색상 순환: 흰 → 노 → 검 → 빨 → 파
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
    private var currentColorIndex = 0
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
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
            ACTION_CLEAR -> {
                overlayView?.clear()
            }
            ACTION_COLOR -> {
                cycleColor()
                updateNotification()
            }
            ACTION_STOP -> {
                hideOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> {
                startForeground(NOTIFICATION_ID, createNotification())
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
        
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }
        
        overlayView = OverlayCanvasView(this)
        overlayView?.setStrokeColor(COLORS[currentColorIndex])
        windowManager?.addView(overlayView, params)
        isOverlayVisible = true
    }
    
    private fun hideOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
        isOverlayVisible = false
    }
    
    private fun cycleColor() {
        currentColorIndex = (currentColorIndex + 1) % COLORS.size
        overlayView?.setStrokeColor(COLORS[currentColorIndex])
    }
    
    private fun updateNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, createNotification())
    }
    
    fun clearCanvas() {
        overlayView?.clear()
    }
    
    fun setColor(color: Int) {
        overlayView?.setStrokeColor(color)
        // 색상 인덱스도 동기화
        val idx = COLORS.indexOf(color)
        if (idx >= 0) currentColorIndex = idx
    }
    
    fun undo() {
        overlayView?.undo()
    }
    
    fun redo() {
        overlayView?.redo()
    }
    
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
            this, 0, mainIntent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        // 토글 버튼
        val toggleIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_TOGGLE
        }
        val togglePendingIntent = PendingIntent.getService(
            this, 1, toggleIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // 색상 버튼
        val colorIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_COLOR
        }
        val colorPendingIntent = PendingIntent.getService(
            this, 2, colorIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // 클리어 버튼
        val clearIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_CLEAR
        }
        val clearPendingIntent = PendingIntent.getService(
            this, 3, clearIntent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        // 종료 버튼
        val stopIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 4, stopIntent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        val statusEmoji = if (isOverlayVisible) "🖊️" else "⏸️"
        val colorEmoji = COLOR_NAMES[currentColorIndex]
        val statusText = "$statusEmoji $colorEmoji"
        val toggleText = if (isOverlayVisible) "OFF" else "ON"
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Laser Pen")
            .setContentText(statusText)
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
