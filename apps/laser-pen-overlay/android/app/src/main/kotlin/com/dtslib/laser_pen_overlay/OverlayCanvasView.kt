package com.dtslib.laser_pen_overlay

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View

class OverlayCanvasView(
    context: Context,
    private val onStylusNear: () -> Unit,
    private val onStylusAway: () -> Unit
) : View(context) {

    companion object {
        private const val TAG = "OverlayCanvasView"
        private const val STYLUS_TIMEOUT_MS = 500L
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

    // S Pen 타임아웃 핸들러
    private val stylusTimeoutHandler = Handler(Looper.getMainLooper())
    private val stylusTimeoutRunnable = Runnable {
        Log.d(TAG, "Stylus timeout - switching to pass-through mode")
        onStylusAway()
    }

    private var isStylusActive = false

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
     */
    private fun isStylus(event: MotionEvent): Boolean {
        for (i in 0 until event.pointerCount) {
            val toolType = event.getToolType(i)
            if (toolType == MotionEvent.TOOL_TYPE_STYLUS ||
                toolType == MotionEvent.TOOL_TYPE_ERASER) {
                return true
            }
        }
        if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
            return true
        }
        return false
    }

    /**
     * S Pen 호버 이벤트 처리 (화면에 닿기 전)
     */
    override fun onHoverEvent(event: MotionEvent): Boolean {
        if (isStylus(event)) {
            when (event.actionMasked) {
                MotionEvent.ACTION_HOVER_ENTER, MotionEvent.ACTION_HOVER_MOVE -> {
                    if (!isStylusActive) {
                        Log.d(TAG, "S Pen hover detected - enabling touch mode")
                        isStylusActive = true
                        onStylusNear()
                    }
                    // 타임아웃 리셋
                    stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
                    stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
                }
                MotionEvent.ACTION_HOVER_EXIT -> {
                    Log.d(TAG, "S Pen hover exit")
                    // 타임아웃 시작
                    stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
                    stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
                }
            }
            return true
        }
        return super.onHoverEvent(event)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        // S Pen 터치만 처리 - 손가락 터치는 아래 앱으로 전달
        if (!isStylus(event)) {
            Log.d(TAG, "Finger touch detected - NOT consuming, passing to app below")
            return false  // false 리턴 → 아래 앱으로 이벤트 전달
        }

        Log.d(TAG, "S Pen touch: action=${event.actionMasked}, pressure=${event.pressure}")

        // S Pen 활성 상태 유지
        if (!isStylusActive) {
            isStylusActive = true
            onStylusNear()
        }
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)

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
                // 펜을 뗀 후 타임아웃 시작
                stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
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

    fun resetStylusState() {
        isStylusActive = false
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        fadeHandler.removeCallbacks(fadeRunnable)
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
    }
}
