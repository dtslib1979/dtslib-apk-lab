package com.dtslib.laser_pen_overlay

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View

class OverlayCanvasView(context: Context) : View(context) {
    
    private val strokes = mutableListOf<StrokeData>()
    private val undoneStrokes = mutableListOf<StrokeData>()
    private var currentStrokeTime: Long = 0
    private var currentSegments = mutableListOf<PathSegment>()
    
    private var strokeColor = Color.WHITE
    private val baseStrokeWidth = 6f
    private val maxStrokeWidth = 16f
    
    private val paint = Paint().apply {
        isAntiAlias = true
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
    }
    
    private val fadeHandler = Handler(Looper.getMainLooper())
    private val fadeRunnable = object : Runnable {
        override fun run() {
            updateFadeAndCleanup()
            invalidate()
            fadeHandler.postDelayed(this, 50)
        }
    }
    
    init {
        setBackgroundColor(Color.TRANSPARENT)
        fadeHandler.post(fadeRunnable)
    }
    
    data class PathSegment(
        val x1: Float, val y1: Float,
        val x2: Float, val y2: Float,
        val width: Float
    )
    
    data class StrokeData(
        val segments: List<PathSegment>,
        val color: Int,
        val createdAt: Long
    ) {
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
    
    private var lastX = 0f
    private var lastY = 0f
    
    /**
     * 핵심: Stylus만 캡처, Finger는 pass-through
     */
    private fun isStylus(event: MotionEvent): Boolean {
        val toolType = event.getToolType(0)
        if (toolType == MotionEvent.TOOL_TYPE_STYLUS ||
            toolType == MotionEvent.TOOL_TYPE_ERASER) {
            return true
        }
        // Fallback: SOURCE_STYLUS 체크
        if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
            return true
        }
        return false
    }
    
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        // Finger → pass-through (하위 앱으로)
        if (!isStylus(event)) {
            return false
        }
        // Stylus → 이 View에서 처리
        return super.dispatchTouchEvent(event)
    }
    
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // dispatchTouchEvent에서 이미 Stylus만 들어옴
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                lastX = event.x
                lastY = event.y
                currentSegments.clear()
                currentStrokeTime = System.currentTimeMillis()
                undoneStrokes.clear()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val pressure = event.pressure.coerceIn(0.1f, 1f)
                val width = baseStrokeWidth + (maxStrokeWidth - baseStrokeWidth) * pressure
                
                currentSegments.add(PathSegment(
                    lastX, lastY,
                    event.x, event.y,
                    width
                ))
                
                lastX = event.x
                lastY = event.y
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (currentSegments.isNotEmpty()) {
                    strokes.add(StrokeData(
                        currentSegments.toList(),
                        strokeColor,
                        currentStrokeTime
                    ))
                    currentSegments.clear()
                }
                invalidate()
                return true
            }
        }
        return false
    }
    
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        
        for (stroke in strokes) {
            val opacity = stroke.getOpacity()
            if (opacity > 0) {
                paint.color = stroke.color
                paint.alpha = (opacity * 255).toInt()
                drawSegments(canvas, stroke.segments, paint)
            }
        }
        
        if (currentSegments.isNotEmpty()) {
            paint.color = strokeColor
            paint.alpha = 255
            drawSegments(canvas, currentSegments, paint)
        }
    }
    
    private fun drawSegments(canvas: Canvas, segments: List<PathSegment>, paint: Paint) {
        for (seg in segments) {
            paint.strokeWidth = seg.width
            canvas.drawLine(seg.x1, seg.y1, seg.x2, seg.y2, paint)
        }
    }
    
    private fun updateFadeAndCleanup() {
        strokes.removeAll { it.isExpired() }
    }
    
    fun clear() {
        strokes.clear()
        undoneStrokes.clear()
        currentSegments.clear()
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
