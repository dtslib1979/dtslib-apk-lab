package com.dtslib.laser_pen_overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
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

    private val colorBtn: TextView
    private var currentColorIndex = 0

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER
        setPadding(16, 8, 16, 8)

        // 반투명 배경
        background = GradientDrawable().apply {
            setColor(Color.argb(200, 40, 40, 40))
            cornerRadius = 40f
        }

        val btnSize = 56
        val btnMargin = 8

        // 색상 버튼
        colorBtn = createButton("⚪", btnSize) {
            onColorClick()
            updateColorButton()
        }
        addButton(colorBtn, btnSize, btnMargin)

        // Undo
        addButton(createButton("◀", btnSize) { onUndoClick() }, btnSize, btnMargin)

        // Redo
        addButton(createButton("▶", btnSize) { onRedoClick() }, btnSize, btnMargin)

        // Clear
        addButton(createButton("🧹", btnSize) { onClearClick() }, btnSize, btnMargin)

        // Close (오버레이 숨기기)
        addButton(createButton("👁", btnSize) { onCloseClick() }, btnSize, btnMargin)
    }

    private fun createButton(text: String, size: Int, onClick: () -> Unit): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 20f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.argb(150, 80, 80, 80))
                cornerRadius = (size / 2).toFloat()
            }
            setOnClickListener { onClick() }
        }
    }

    private fun addButton(view: View, size: Int, margin: Int) {
        val params = LayoutParams(size, size).apply {
            setMargins(margin, 0, margin, 0)
        }
        addView(view, params)
    }

    fun updateColorButton() {
        currentColorIndex = (currentColorIndex + 1) % OverlayService.COLOR_NAMES.size
        colorBtn.text = OverlayService.COLOR_NAMES[currentColorIndex]
    }

    fun setColorIndex(index: Int) {
        currentColorIndex = index
        colorBtn.text = OverlayService.COLOR_NAMES[currentColorIndex]
    }
}
