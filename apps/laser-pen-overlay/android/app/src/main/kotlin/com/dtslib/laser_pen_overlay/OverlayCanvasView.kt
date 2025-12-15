package com.dtslib.laser_pen_overlay

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View

class OverlayCanvasView(context: Context) : View(context) {

    companion object {
        private const val TAG = "OverlayCanvasView"
    }

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
     * S Pen / Stylus 감지
     * - TOOL_TYPE_STYLUS (2): S Pen 직접 터치
     * - TOOL_TYPE_ERASER (4): S Pen 지우개 모드
     * - SOURCE_STYLUS: 디바이스 소스 체크 (폴백)
     */
    private fun isStylus(event: MotionEvent): Boolean {
        // 모든 포인터 체크 (멀티터치 대응)
        for (i in 0 until event.pointerCount) {
            val toolType = event.getToolType(i)
            if (toolType == MotionEvent.TOOL_TYPE_STYLUS ||
                toolType == MotionEvent.TOOL_TYPE_ERASER) {
                return true
            }
        }
        // Fallback: SOURCE_STYLUS 체크
        if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
            return true
        }
        return false
    }

    /**
     * 터치 분리 핵심 로직:
     * - S Pen: 이 View에서 처리 (그리기)
     * - 손가락: return false → FLAG_SLIPPERY에 의해 하위 앱으로 전달
     */
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        val isStylusEvent = isStylus(event)

        if (!isStylusEvent) {
            // 손가락 터치 → 하위 앱으로 pass-through
            // FLAG_SLIPPERY 플래그와 함께 동작하여 하위 앱에서 스크롤 가능
            Log.v(TAG, "Finger touch detected, passing through: action=${event.actionMasked}")
            return false
        }

        // S Pen 터치 → 이 View에서 처리
        Log.v(TAG, "Stylus touch detected, handling: action=${event.actionMasked}, pressure=${event.pressure}")
        return super.dispatchTouchEvent(event)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        // dispatchTouchEvent에서 이미 Stylus만 들어옴
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                lastX = event.x
                lastY = event.y
                currentSegments.clear()
                currentStrokeTime = System.currentTimeMillis()
                undoneStrokes.clear()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                // S Pen 필압 감지 (0.0 ~ 1.0)
                val pressure = event.pressure.coerceIn(0.1f, 1f)
                val width = baseStrokeWidth + (maxStrokeWidth - baseStrokeWidth) * pressure

                // 히스토리 이벤트 처리 (부드러운 선)
                for (h in 0 until event.historySize) {
                    val hPressure = event.getHistoricalPressure(h).coerceIn(0.1f, 1f)
                    val hWidth = baseStrokeWidth + (maxStrokeWidth - baseStrokeWidth) * hPressure
                    currentSegments.add(PathSegment(
                        lastX, lastY,
                        event.getHistoricalX(h), event.getHistoricalY(h),
                        hWidth
                    ))
                    lastX = event.getHistoricalX(h)
                    lastY = event.getHistoricalY(h)
                }

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
