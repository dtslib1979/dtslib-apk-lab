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
    private val onCloseClick: () -> Unit
) : LinearLayout(context) {

    companion object {
        const val TAG = "FloatingControlBar"
    }

    private val colorBtn: TextView
    private var currentColorIndex = 0

    private fun Int.dp(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        this.toFloat(),
        context.resources.displayMetrics
    ).toInt()

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER
        setPadding(16.dp(), 8.dp(), 16.dp(), 8.dp())

        background = GradientDrawable().apply {
            setColor(Color.argb(220, 30, 30, 30))
            cornerRadius = 30.dp().toFloat()
        }

        val btnSize = 48.dp()
        val btnMargin = 6.dp()

        // 색상 버튼
        colorBtn = createButton("⚪", btnSize) {
            Log.d(TAG, "Color button clicked")
            onColorClick()
        }
        addButton(colorBtn, btnSize, btnMargin)

        // Undo
        addButton(createButton("◀", btnSize) {
            Log.d(TAG, "Undo button clicked")
            onUndoClick()
        }, btnSize, btnMargin)

        // Redo
        addButton(createButton("▶", btnSize) {
            Log.d(TAG, "Redo button clicked")
            onRedoClick()
        }, btnSize, btnMargin)

        // Clear
        addButton(createButton("🧹", btnSize) {
            Log.d(TAG, "Clear button clicked")
            onClearClick()
        }, btnSize, btnMargin)

        // Close (오버레이 숨기기) - 더 눈에 띄게
        val closeBtn = createButton("✕", btnSize) {
            Log.d(TAG, "Close button clicked")
            onCloseClick()
        }
        closeBtn.setTextColor(Color.RED)
        addButton(closeBtn, btnSize, btnMargin)
    }

    private fun createButton(text: String, size: Int, onClick: () -> Unit): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.argb(180, 60, 60, 60))
                cornerRadius = (size / 2).toFloat()
            }
            isClickable = true
            isFocusable = true
            
            // 터치 이벤트 직접 처리
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
    
    /**
     * 컨트롤 바는 항상 터치 소비 (finger 포함)
     */
    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        return super.dispatchTouchEvent(ev)
    }
}
