package com.dtslib.overlaydualsub.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.dtslib.overlaydualsub.overlay.OverlayWindowController

class OverlayService : Service() {

    companion object {
        const val CH_ID = "overlay_sub_ch"
        const val NOTIF_ID = 1001
    }

    private var useMock = true
    private var controller: OverlayWindowController? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        useMock = intent?.getBooleanExtra("useMock", true) ?: true
        startForeground(NOTIF_ID, buildNotif())
        
        // Initialize overlay
        if (controller == null) {
            controller = OverlayWindowController(this)
            controller?.show()
        }
        
        return START_STICKY
    }

    override fun onDestroy() {
        controller?.hide()
        controller = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        val ch = NotificationChannel(
            CH_ID,
            "Overlay Subtitle",
            NotificationManager.IMPORTANCE_LOW
        )
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(ch)
    }

    private fun buildNotif(): Notification {
        return NotificationCompat.Builder(this, CH_ID)
            .setContentTitle("Dual Subtitle")
            .setContentText("자막 오버레이 실행 중")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }
}
