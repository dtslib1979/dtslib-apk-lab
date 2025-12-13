package com.dtslib.laser_pen_overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

@SuppressLint("ViewConstructor", "ClickableViewAccessibility")
class FloatingControlBar(
    context: Context,
    private val onColorClick: () -> Unit,
    private val onUndoClick: () -> Unit,
    private val onRedoClick: () -> Unit,
    private val onClearClick: () -> Unit,
    private val onCloseClick: () -> Unit,
    private val onPositionChanged: ((Int, Int) -> Unit)? = null
) : LinearLayout(context) {

    private val colorBtn: TextView
    private var currentColorIndex = 0
    
    // 드래그 상태
    private var isDragging = false
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f

    private fun Int.dp(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        this.toFloat(),
        context.resources.displayMetrics
    ).toInt()

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER
        setPadding(12.dp(), 8.dp(), 12.dp(), 8.dp())

        background = GradientDrawable().apply {
            setColor(Color.argb(230, 25, 25, 25))
            cornerRadius = 28.dp().toFloat()
            setStroke(1.dp(), Color.argb(100, 255, 255, 255))
        }

        val btnSize = 44.dp()
        val btnMargin = 4.dp()

        // 드래그 핸들
        val dragHandle = TextView(context).apply {
            text = "⋮⋮"
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.argb(150, 255, 255, 255))
        }
        addButton(dragHandle, 28.dp(), btnMargin)

        // 색상 버튼
        colorBtn = createButton("⚪", btnSize) { onColorClick() }
        addButton(colorBtn, btnSize, btnMargin)

        // Undo
        addButton(createButton("◀", btnSize) { onUndoClick() }, btnSize, btnMargin)

        // Redo
        addButton(createButton("▶", btnSize) { onRedoClick() }, btnSize, btnMargin)

        // Clear
        addButton(createButton("🧹", btnSize) { onClearClick() }, btnSize, btnMargin)

        // Close
        addButton(createButton("👁", btnSize) { onCloseClick() }, btnSize, btnMargin)

        setupDragListener()
    }

    private fun setupDragListener() {
        setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    
                    val params = layoutParams as? WindowManager.LayoutParams
                    if (params != null) {
                        initialX = params.x
                        initialY = params.y
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    
                    if (!isDragging && (Math.abs(dx) > 10 || Math.abs(dy) > 10)) {
                        isDragging = true
                    }
                    
                    if (isDragging) {
                        val newX = initialX + dx.toInt()
                        val newY = initialY - dy.toInt()
                        onPositionChanged?.invoke(newX, newY)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        performClick()
                    }
                    isDragging = false
                    true
                }
                else -> false
            }
        }
    }

    private fun createButton(text: String, size: Int, onClick: () -> Unit): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.argb(0, 0, 0, 0))
                cornerRadius = (size / 2).toFloat()
            }
            setOnClickListener { 
                if (!isDragging) onClick() 
            }
        }
    }

    private fun addButton(view: View, size: Int, margin: Int) {
        val params = LayoutParams(size, size).apply {
            setMargins(margin, 0, margin, 0)
        }
        addView(view, params)
    }

    fun setColorIndex(index: Int) {
        currentColorIndex = index
        colorBtn.text = OverlayService.COLOR_NAMES[currentColorIndex]
    }
}
