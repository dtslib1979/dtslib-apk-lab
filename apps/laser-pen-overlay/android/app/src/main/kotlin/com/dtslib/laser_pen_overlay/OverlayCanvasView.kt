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

/**
 * 통합 오버레이 캔버스 뷰
 *
 * 핵심 로직:
 * 1. 호버 이벤트로 S Pen 감지 → onStylusStateChanged(true) 호출
 * 2. S Pen 떠남 감지 → onStylusStateChanged(false) 호출
 * 3. 서비스에서 FLAG_NOT_TOUCHABLE 토글로 손가락/펜 분리
 */
class OverlayCanvasView(
    context: Context,
    private val onStylusStateChanged: (Boolean) -> Unit
) : View(context) {

    companion object {
        private const val TAG = "OverlayCanvas"
        private const val STYLUS_TIMEOUT_MS = 300L  // 짧게 설정
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

    private val stylusTimeoutHandler = Handler(Looper.getMainLooper())
    private val stylusTimeoutRunnable = Runnable {
        Log.i(TAG, ">>> S Pen TIMEOUT - 손가락 터치 모드로 전환")
        isStylusNear = false
        onStylusStateChanged(false)
    }

    @Volatile
    private var isStylusNear = false

    private var lastX = 0f
    private var lastY = 0f

    init {
        setBackgroundColor(Color.TRANSPARENT)
        fadeHandler.post(fadeRunnable)
        Log.i(TAG, "OverlayCanvasView 생성됨")
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

        fun isExpired() = System.currentTimeMillis() - createdAt > 3500
    }

    /**
     * S Pen / Stylus 감지 (삼성 S Pen 포함)
     */
    private fun isStylus(event: MotionEvent): Boolean {
        // 방법 1: toolType 체크
        for (i in 0 until event.pointerCount) {
            when (event.getToolType(i)) {
                MotionEvent.TOOL_TYPE_STYLUS,
                MotionEvent.TOOL_TYPE_ERASER -> return true
            }
        }
        // 방법 2: source 체크 (구형 기기 대응)
        if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
            return true
        }
        // 방법 3: 삼성 S Pen은 pressure와 함께 오는 경우가 많음
        if (event.pressure > 0 && event.pressure != 1.0f) {
            // 추가 검증 필요하면 여기서
        }
        return false
    }

    /**
     * 호버 이벤트 - S Pen 감지의 핵심!
     * S Pen이 화면 가까이 오면 호출됨 (터치 전)
     */
    override fun onHoverEvent(event: MotionEvent): Boolean {
        val stylus = isStylus(event)
        Log.d(TAG, "onHoverEvent: action=${event.actionMasked}, isStylus=$stylus, x=${event.x}, y=${event.y}")

        if (stylus) {
            when (event.actionMasked) {
                MotionEvent.ACTION_HOVER_ENTER -> {
                    Log.i(TAG, ">>> S Pen HOVER ENTER - 터치 모드 활성화")
                    activateStylus()
                }
                MotionEvent.ACTION_HOVER_MOVE -> {
                    if (!isStylusNear) {
                        Log.i(TAG, ">>> S Pen HOVER MOVE (재활성화)")
                        activateStylus()
                    }
                    resetTimeout()
                }
                MotionEvent.ACTION_HOVER_EXIT -> {
                    Log.i(TAG, ">>> S Pen HOVER EXIT - 타임아웃 시작")
                    startTimeout()
                }
            }
            return true
        }
        return super.onHoverEvent(event)
    }

    /**
     * 제네릭 모션 이벤트 (일부 기기에서 호버를 여기로 보냄)
     */
    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_HOVER_ENTER ||
            event.actionMasked == MotionEvent.ACTION_HOVER_MOVE) {
            if (isStylus(event)) {
                Log.d(TAG, "onGenericMotionEvent: S Pen hover detected")
                if (!isStylusNear) {
                    activateStylus()
                }
                resetTimeout()
                return true
            }
        }
        return super.onGenericMotionEvent(event)
    }

    /**
     * 터치 이벤트 - S Pen 그리기 처리
     * FLAG_NOT_TOUCHABLE이 해제된 상태에서만 호출됨
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val stylus = isStylus(event)
        Log.d(TAG, "onTouchEvent: action=${event.actionMasked}, isStylus=$stylus, pressure=${event.pressure}")

        // S Pen이 아닌 터치는 무시 (FLAG_NOT_TOUCHABLE이 해제된 상태에서 손가락이 올 수 있음)
        if (!stylus) {
            Log.w(TAG, "손가락 터치 감지 - 이벤트 무시 (false 반환)")
            return false
        }

        // S Pen 상태 유지
        if (!isStylusNear) {
            Log.i(TAG, "S Pen 터치로 활성화")
            activateStylus()
        }
        resetTimeout()

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                lastX = event.x
                lastY = event.y
                currentSegments.clear()
                currentStrokeTime = System.currentTimeMillis()
                undoneStrokes.clear()
                Log.d(TAG, "그리기 시작: ($lastX, $lastY)")
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val pressure = event.pressure.coerceIn(0.1f, 1f)
                val width = baseStrokeWidth + (maxStrokeWidth - baseStrokeWidth) * pressure

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

                currentSegments.add(PathSegment(lastX, lastY, event.x, event.y, width))
                lastX = event.x
                lastY = event.y
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (currentSegments.isNotEmpty()) {
                    strokes.add(StrokeData(currentSegments.toList(), strokeColor, currentStrokeTime))
                    currentSegments.clear()
                    Log.d(TAG, "그리기 완료: ${strokes.size}개 스트로크")
                }
                invalidate()
                startTimeout()
                return true
            }
        }
        return true
    }

    private fun activateStylus() {
        isStylusNear = true
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
        onStylusStateChanged(true)
    }

    private fun resetTimeout() {
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
        stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
    }

    private fun startTimeout() {
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
        stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        for (stroke in strokes) {
            val opacity = stroke.getOpacity()
            if (opacity > 0) {
                paint.color = stroke.color
                paint.alpha = (opacity * 255).toInt()
                drawSegments(canvas, stroke.segments)
            }
        }

        if (currentSegments.isNotEmpty()) {
            paint.color = strokeColor
            paint.alpha = 255
            drawSegments(canvas, currentSegments)
        }
    }

    private fun drawSegments(canvas: Canvas, segments: List<PathSegment>) {
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
        isStylusNear = false
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
    }

    fun isStylusCurrentlyNear() = isStylusNear

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        fadeHandler.removeCallbacks(fadeRunnable)
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
    }
}
