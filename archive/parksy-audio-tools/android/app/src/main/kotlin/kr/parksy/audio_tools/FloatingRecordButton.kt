package kr.parksy.audio_tools

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * Floating Record Button with timer display
 * - Shows recording status (REC / STOP)
 * - Timer display
 * - Draggable
 * - Close button
 */
@SuppressLint("ViewConstructor")
class FloatingRecordButton(
    context: Context,
    private val onRecordClick: () -> Unit,
    private val onCloseClick: () -> Unit,
    private val onDrag: (dx: Int, dy: Int) -> Unit
) : LinearLayout(context) {

    private val recordBtn: ImageView
    private val timerText: TextView
    private val closeBtn: ImageView

    private var isRecording = false
    private var isDragging = false
    private var lastX = 0f
    private var lastY = 0f
    private var startX = 0f
    private var startY = 0f

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(12.dp, 8.dp, 12.dp, 8.dp)

        // Background
        background = GradientDrawable().apply {
            setColor(Color.parseColor("#E0000000"))
            cornerRadius = 24.dp.toFloat()
        }

        // Record button
        recordBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.presence_audio_online)
            setColorFilter(Color.WHITE)
            layoutParams = LayoutParams(40.dp, 40.dp)
        }
        addView(recordBtn)

        // Timer text
        timerText = TextView(context).apply {
            text = "0:00"
            setTextColor(Color.WHITE)
            textSize = 16f
            setPadding(12.dp, 0, 12.dp, 0)
        }
        addView(timerText)

        // Close button
        closeBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.parseColor("#AAAAAA"))
            layoutParams = LayoutParams(32.dp, 32.dp)
        }
        addView(closeBtn)

        setupTouchListeners()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupTouchListeners() {
        // Record button click
        recordBtn.setOnClickListener {
            if (!isDragging) onRecordClick()
        }

        // Close button click
        closeBtn.setOnClickListener {
            if (!isDragging) onCloseClick()
        }

        // Drag handling
        setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    startX = event.rawX
                    startY = event.rawY
                    lastX = event.rawX
                    lastY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - lastX
                    val dy = event.rawY - lastY

                    if (!isDragging && (abs(event.rawX - startX) > 10 || abs(event.rawY - startY) > 10)) {
                        isDragging = true
                    }

                    if (isDragging) {
                        onDrag(dx.toInt(), dy.toInt())
                        lastX = event.rawX
                        lastY = event.rawY
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (isDragging) {
                        isDragging = false
                    }
                    true
                }
                else -> false
            }
        }
    }

    fun setRecording(recording: Boolean) {
        isRecording = recording
        if (recording) {
            recordBtn.setColorFilter(Color.RED)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E0300000"))
                cornerRadius = 24.dp.toFloat()
            }
        } else {
            recordBtn.setColorFilter(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E0000000"))
                cornerRadius = 24.dp.toFloat()
            }
            timerText.text = "0:00"
        }
    }

    fun updateTimer(seconds: Int) {
        val m = seconds / 60
        val s = seconds % 60
        timerText.text = String.format("%d:%02d", m, s)
    }

    private val Int.dp: Int
        get() = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            this.toFloat(),
            resources.displayMetrics
        ).toInt()
}
