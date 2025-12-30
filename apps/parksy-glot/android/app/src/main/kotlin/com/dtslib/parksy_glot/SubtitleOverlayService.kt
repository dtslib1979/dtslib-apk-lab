package com.dtslib.parksy_glot

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.IBinder
import android.util.TypedValue
import android.view.*
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class SubtitleOverlayService : Service() {

    companion object {
        private var instance: SubtitleOverlayService? = null
        private var overlayView: View? = null
        private var windowManager: WindowManager? = null
        private var isVisible = false

        private var koreanText: TextView? = null
        private var englishText: TextView? = null
        private var originalText: TextView? = null
        private var originalContainer: View? = null

        private var fontScale = 1.0f

        fun showOverlay() {
            instance?.showOverlayInternal()
        }

        fun hideOverlay() {
            instance?.hideOverlayInternal()
        }

        fun isVisible(): Boolean = isVisible

        fun updateSubtitle(korean: String, english: String, original: String, showOriginal: Boolean) {
            instance?.updateSubtitleInternal(korean, english, original, showOriginal)
        }

        fun setFontScale(scale: Float) {
            fontScale = scale
            instance?.updateFontScale()
        }

        fun toggleOriginal(show: Boolean) {
            originalContainer?.visibility = if (show) View.VISIBLE else View.GONE
        }
    }

    private val CHANNEL_ID = "parksy_glot_overlay"
    private val NOTIFICATION_ID = 1001

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        hideOverlayInternal()
        instance = null
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Parksy Glot Subtitle",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "실시간 자막 오버레이"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Parksy Glot")
            .setContentText("실시간 자막 활성화")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun showOverlayInternal() {
        if (isVisible || overlayView != null) return

        overlayView = createOverlayView()

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = 100 // Bottom margin
        }

        windowManager?.addView(overlayView, params)
        isVisible = true
    }

    private fun createOverlayView(): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#DD000000"))
            setPadding(dp(20), dp(14), dp(20), dp(14))
        }

        // Korean text
        koreanText = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f * fontScale)
            typeface = Typeface.DEFAULT_BOLD
            text = ""
        }
        container.addView(koreanText)

        // English text
        englishText = TextView(this).apply {
            setTextColor(Color.parseColor("#D9FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f * fontScale)
            setPadding(0, dp(6), 0, 0)
            text = ""
        }
        container.addView(englishText)

        // Original text container (accordion)
        originalContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            setPadding(0, dp(10), 0, 0)
        }

        val divider = View(this).apply {
            setBackgroundColor(Color.parseColor("#33FFFFFF"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(1)
            )
        }
        (originalContainer as LinearLayout).addView(divider)

        originalText = TextView(this).apply {
            setTextColor(Color.parseColor("#B3FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f * fontScale)
            setPadding(0, dp(8), 0, 0)
            text = ""
        }
        (originalContainer as LinearLayout).addView(originalText)

        container.addView(originalContainer)

        return container
    }

    private fun hideOverlayInternal() {
        if (!isVisible || overlayView == null) return

        try {
            windowManager?.removeView(overlayView)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        overlayView = null
        koreanText = null
        englishText = null
        originalText = null
        originalContainer = null
        isVisible = false
    }

    private fun updateSubtitleInternal(korean: String, english: String, original: String, showOriginal: Boolean) {
        koreanText?.text = korean
        englishText?.text = english
        originalText?.text = original
        originalContainer?.visibility = if (showOriginal && original.isNotEmpty()) View.VISIBLE else View.GONE
    }

    private fun updateFontScale() {
        koreanText?.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f * fontScale)
        englishText?.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f * fontScale)
        originalText?.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f * fontScale)
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
