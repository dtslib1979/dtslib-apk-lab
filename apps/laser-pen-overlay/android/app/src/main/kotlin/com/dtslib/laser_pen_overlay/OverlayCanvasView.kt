package com.dtslib.laser_pen_overlay

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View

class OverlayCanvasView(context: Context) : View(context) {
    
    private val strokes = mutableListOf<StrokeData>()
    private val undoneStrokes = mutableListOf<StrokeData>()
    private var currentPath: Path? = null
    private var currentStrokeTime: Long = 0
    
    private var strokeColor = Color.WHITE
    private val strokeWidth = 8f
    
    private val paint = Paint().apply {
        isAntiAlias = true
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
        strokeWidth = this@OverlayCanvasView.strokeWidth
    }
    
    private val fadeHandler = Handler(Looper.getMainLooper())
    private val fadeRunnable = object : Runnable {
        override fun run() {
            updateFadeAndCleanup()
            invalidate()
            fadeHandler.postDelayed(this, 50) // 20fps for fade animation
        }
    }
    
    init {
        // 배경 투명
        setBackgroundColor(Color.TRANSPARENT)
        fadeHandler.post(fadeRunnable)
    }
    
    data class StrokeData(
        val path: Path,
        val color: Int,
        val createdAt: Long
    ) {
        // 3초 후 fade 시작, 3.5초에 완전 투명
        fun getOpacity(): Float {
            val elapsed = System.currentTimeMillis() - createdAt
            return when {
                elapsed < 3000 -> 1f
                elapsed > 3500 -> 0f
                else -> 1f - ((elapsed - 3000) / 500f)
            }
        }
        
        fun isExpired(): Boolean {
            return System.currentTimeMillis() - createdAt > 3500
        }
    }
    
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val toolType = event.getToolType(0)
        
        // S Pen (STYLUS/ERASER)만 처리
        if (toolType != MotionEvent.TOOL_TYPE_STYLUS && 
            toolType != MotionEvent.TOOL_TYPE_ERASER) {
            // 손가락 입력은 무시 → 하위 앱으로 pass-through
            return false
        }
        
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                currentPath = Path().apply {
                    moveTo(event.x, event.y)
                }
                currentStrokeTime = System.currentTimeMillis()
                undoneStrokes.clear() // 새 스트로크 시작하면 redo 스택 클리어
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                currentPath?.lineTo(event.x, event.y)
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                currentPath?.let { path ->
                    strokes.add(StrokeData(path, strokeColor, currentStrokeTime))
                }
                currentPath = null
                invalidate()
                return true
            }
        }
        return super.onTouchEvent(event)
    }
    
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        
        // 저장된 스트로크 렌더링 (fade 적용)
        for (stroke in strokes) {
            val opacity = stroke.getOpacity()
            if (opacity > 0) {
                paint.color = stroke.color
                paint.alpha = (opacity * 255).toInt()
                canvas.drawPath(stroke.path, paint)
            }
        }
        
        // 현재 그리는 중인 스트로크
        currentPath?.let { path ->
            paint.color = strokeColor
            paint.alpha = 255
            canvas.drawPath(path, paint)
        }
    }
    
    private fun updateFadeAndCleanup() {
        // 만료된 스트로크 제거
        strokes.removeAll { it.isExpired() }
    }
    
    fun clear() {
        strokes.clear()
        undoneStrokes.clear()
        invalidate()
    }
    
    fun setStrokeColor(color: Int) {
        strokeColor = color
    }
    
    fun undo() {
        if (strokes.isNotEmpty()) {
            undoneStrokes.add(strokes.removeLast())
            invalidate()
        }
    }
    
    fun redo() {
        if (undoneStrokes.isNotEmpty()) {
            strokes.add(undoneStrokes.removeLast())
            invalidate()
        }
    }
    
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        fadeHandler.removeCallbacks(fadeRunnable)
    }
}
