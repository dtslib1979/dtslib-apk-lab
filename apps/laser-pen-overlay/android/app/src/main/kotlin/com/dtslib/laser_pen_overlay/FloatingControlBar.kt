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
import kotlin.math.abs

@SuppressLint("ViewConstructor", "ClickableViewAccessibility")
class FloatingControlBar(
    context: Context,
    private val onColorChange: (Int) -> Unit, // 색상 인덱스 전달
    private val onUndoClick: () -> Unit,
    private val onRedoClick: () -> Unit,
    private val onClearClick: () -> Unit,
    private val onCloseClick: () -> Unit,
    private val onPositionChanged: ((Int, Int) -> Unit)? = null
) : LinearLayout(context) {

    private val colorBtn: TextView
    private var currentColorIndex = 0
    
    // 제스처 상태
    private var isDragging = false
    private var isSwipe = false
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    
    private val SWIPE_THRESHOLD = 80f
    private val DRAG_THRESHOLD = 15f

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

        // 색상 버튼 (탭: 순환, 스와이프: 방향별 전환)
        colorBtn = createButton("⚪", btnSize) { cycleColor(1) }
        addButton(colorBtn, btnSize, btnMargin)

        // Undo
        addButton(createButton("◀", btnSize) { onUndoClick() }, btnSize, btnMargin)

        // Redo
        addButton(createButton("▶", btnSize) { onRedoClick() }, btnSize, btnMargin)

        // Clear
        addButton(createButton("🧹", btnSize) { onClearClick() }, btnSize, btnMargin)

        // Close
        addButton(createButton("👁", btnSize) { onCloseClick() }, btnSize, btnMargin)

        setupGestureListener()
    }

    private fun setupGestureListener() {
        setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    isSwipe = false
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
                    
                    // 드래그 감지 (수직 이동 우선)
                    if (!isDragging && !isSwipe && abs(dy) > DRAG_THRESHOLD) {
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
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    
                    // 스와이프 감지 (수평 이동 + 수직 이동 적음)
                    if (!isDragging && abs(dx) > SWIPE_THRESHOLD && abs(dy) < SWIPE_THRESHOLD) {
                        isSwipe = true
                        if (dx > 0) {
                            // 오른쪽 스와이프 → 다음 색상
                            cycleColor(1)
                        } else {
                            // 왼쪽 스와이프 → 이전 색상
                            cycleColor(-1)
                        }
                    } else if (!isDragging && !isSwipe) {
                        performClick()
                    }
                    
                    isDragging = false
                    isSwipe = false
                    true
                }
                else -> false
            }
        }
    }
    
    private fun cycleColor(direction: Int) {
        val size = OverlayService.COLOR_NAMES.size
        currentColorIndex = (currentColorIndex + direction + size) % size
        colorBtn.text = OverlayService.COLOR_NAMES[currentColorIndex]
        onColorChange(currentColorIndex)
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
                if (!isDragging && !isSwipe) onClick() 
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
