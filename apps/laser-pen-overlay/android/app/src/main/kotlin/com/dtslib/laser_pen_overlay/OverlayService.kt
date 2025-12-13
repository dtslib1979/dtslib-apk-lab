package com.dtslib.laser_pen_overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
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
        const val ACTION_STOP = "com.dtslib.laser_pen_overlay.STOP"
        
        var instance: OverlayService? = null
        var isOverlayVisible = false
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: OverlayCanvasView? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> showOverlay()
            ACTION_HIDE -> hideOverlay()
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
            // 핵심: S Pen만 받고, 손가락은 통과
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
        windowManager?.addView(overlayView, params)
        isOverlayVisible = true
        
        // 알림 업데이트
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, createNotification())
    }
    
    private fun hideOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
        isOverlayVisible = false
    }
    
    fun clearCanvas() {
        overlayView?.clear()
    }
    
    fun setColor(color: Int) {
        overlayView?.setStrokeColor(color)
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
        val pendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        val stopIntent = Intent(this, OverlayService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        val statusText = if (isOverlayVisible) "판서 활성화" else "대기 중"
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Laser Pen")
            .setContentText(statusText)
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "종료",
                stopPendingIntent
            )
            .setOngoing(true)
            .build()
    }
}
