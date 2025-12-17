package com.dtslib.laser_pen_overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

@SuppressLint("ViewConstructor")
class FloatingControlBar(
    context: Context,
    private val onColorClick: () -> Unit,
    private val onUndoClick: () -> Unit,
    private val onRedoClick: () -> Unit,
    private val onClearClick: () -> Unit,
    private val onCloseClick: () -> Unit,
    private val onDrag: (Int, Int) -> Unit  // 드래그 콜백 (deltaX, deltaY)
) : LinearLayout(context) {

    companion object {
        const val TAG = "FloatingControlBar"
        private const val DRAG_THRESHOLD = 10
    }

    private val colorBtn: TextView
    private var currentColorIndex = 0

    // 드래그 관련 변수
    private var isDragging = false
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var dragStartX = 0f
    private var dragStartY = 0f

    private fun Int.dp(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        this.toFloat(),
        context.resources.displayMetrics
    ).toInt()

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER
        setPadding(16.dp(), 8.dp(), 16.dp(), 8.dp())

        // 극단적 투명 - 거의 안 보임 (녹화용)
        background = GradientDrawable().apply {
            setColor(Color.argb(8, 30, 30, 30))  // 거의 투명
            cornerRadius = 30.dp().toFloat()
        }

        val btnSize = 44.dp()
        val btnMargin = 4.dp()

        // 드래그 핸들 (왼쪽) - 극단 투명
        val dragHandle = createGhostHandle(btnSize)
        addButton(dragHandle, btnSize, btnMargin)

        // 색상 버튼 - 극단 투명
        colorBtn = createGhostButton("⚪", btnSize) {
            Log.d(TAG, "Color button clicked")
            onColorClick()
        }
        addButton(colorBtn, btnSize, btnMargin)

        // Undo
        addButton(createGhostButton("◀", btnSize) {
            Log.d(TAG, "Undo button clicked")
            onUndoClick()
        }, btnSize, btnMargin)

        // Redo
        addButton(createGhostButton("▶", btnSize) {
            Log.d(TAG, "Redo button clicked")
            onRedoClick()
        }, btnSize, btnMargin)

        // Clear
        addButton(createGhostButton("🧹", btnSize) {
            Log.d(TAG, "Clear button clicked")
            onClearClick()
        }, btnSize, btnMargin)

        // Close (오버레이 숨기기)
        val closeBtn = createGhostButton("✕", btnSize) {
            Log.d(TAG, "Close button clicked")
            onCloseClick()
        }
        closeBtn.setTextColor(Color.argb(12, 255, 0, 0))  // 극단 투명 빨강
        addButton(closeBtn, btnSize, btnMargin)
    }

    // 핸들만 살짝 보이게 (나머지는 극단 투명)
    @SuppressLint("ClickableViewAccessibility")
    private fun createGhostHandle(size: Int): TextView {
        return TextView(context).apply {
            text = "⋮"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.argb(50, 255, 255, 255))  // 살짝 보임
            background = GradientDrawable().apply {
                setColor(Color.argb(25, 100, 100, 100))  // 희미하게
                cornerRadius = (size / 2).toFloat()
            }

            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        isDragging = false
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        dragStartX = event.rawX
                        dragStartY = event.rawY
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val deltaX = event.rawX - dragStartX
                        val deltaY = event.rawY - dragStartY

                        if (!isDragging && (Math.abs(deltaX) > DRAG_THRESHOLD || Math.abs(deltaY) > DRAG_THRESHOLD)) {
                            isDragging = true
                        }

                        if (isDragging) {
                            onDrag(deltaX.toInt(), deltaY.toInt())
                            dragStartX = event.rawX
                            dragStartY = event.rawY
                        }
                        true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        isDragging = false
                        true
                    }
                    else -> false
                }
            }
        }
    }

    // 극단 투명 버튼
    private fun createGhostButton(text: String, size: Int, onClick: () -> Unit): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.argb(12, 255, 255, 255))  // 극단 투명
            background = GradientDrawable().apply {
                setColor(Color.argb(5, 60, 60, 60))  // 거의 안 보임
                cornerRadius = (size / 2).toFloat()
            }
            isClickable = true
            isFocusable = true

            setOnTouchListener { v, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        // 터치 시 잠깐 보이게
                        v.alpha = 0.5f
                        (v as TextView).setTextColor(Color.argb(180, 255, 255, 255))
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        v.alpha = 1.0f
                        (v as TextView).setTextColor(Color.argb(12, 255, 255, 255))
                        onClick()
                        true
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        v.alpha = 1.0f
                        (v as TextView).setTextColor(Color.argb(12, 255, 255, 255))
                        true
                    }
                    else -> false
                }
            }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createDragHandle(size: Int): TextView {
        return TextView(context).apply {
            text = "⋮⋮"
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.GRAY)
            background = GradientDrawable().apply {
                setColor(Color.argb(100, 80, 80, 80))
                cornerRadius = (size / 2).toFloat()
            }

            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        isDragging = false
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        dragStartX = event.rawX
                        dragStartY = event.rawY
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val deltaX = event.rawX - dragStartX
                        val deltaY = event.rawY - dragStartY

                        if (!isDragging && (Math.abs(deltaX) > DRAG_THRESHOLD || Math.abs(deltaY) > DRAG_THRESHOLD)) {
                            isDragging = true
                        }

                        if (isDragging) {
                            onDrag(deltaX.toInt(), deltaY.toInt())
                            dragStartX = event.rawX
                            dragStartY = event.rawY
                        }
                        true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        isDragging = false
                        true
                    }
                    else -> false
                }
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
                setColor(Color.argb(180, 60, 60, 60))
                cornerRadius = (size / 2).toFloat()
            }
            isClickable = true
            isFocusable = true

            setOnTouchListener { v, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        v.alpha = 0.7f
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        v.alpha = 1.0f
                        onClick()
                        true
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        v.alpha = 1.0f
                        true
                    }
                    else -> false
                }
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
