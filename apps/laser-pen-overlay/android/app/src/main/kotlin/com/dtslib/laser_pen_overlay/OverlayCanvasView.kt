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
 * S Pen / 손가락 분리 오버레이 캔버스
 *
 * 핵심 로직:
 * 1. 모든 터치 이벤트 수신 (FLAG_NOT_TOUCHABLE 없음)
 * 2. S Pen → 캔버스에 그리기
 * 3. 손가락 → TouchInjectionService로 전달하여 아래 앱에 주입
 */
class OverlayCanvasView(
    context: Context,
    private val onInputModeChanged: ((isStylus: Boolean) -> Unit)? = null
) : View(context) {

    companion object {
        private const val TAG = "OverlayCanvas"
        private const val FADE_DURATION_MS = 3500L
        private const val FADE_START_MS = 3000L
    }

    // 스트로크 데이터
    private val strokes = mutableListOf<StrokeData>()
    private val undoneStrokes = mutableListOf<StrokeData>()
    private var currentSegments = mutableListOf<PathSegment>()
    private var currentStrokeTime: Long = 0

    // 그리기 설정
    private var strokeColor = Color.WHITE
    private val baseStrokeWidth = 6f
    private val maxStrokeWidth = 16f

    private val paint = Paint().apply {
        isAntiAlias = true
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
    }

    // 페이드 아웃 핸들러
    private val fadeHandler = Handler(Looper.getMainLooper())
    private val fadeRunnable = object : Runnable {
        override fun run() {
            updateFadeAndCleanup()
            invalidate()
            fadeHandler.postDelayed(this, 50)
        }
    }

    // 마지막 좌표
    private var lastX = 0f
    private var lastY = 0f

    // 현재 입력 모드 추적
    private var currentInputIsStylus = false

    init {
        setBackgroundColor(Color.TRANSPARENT)
        fadeHandler.post(fadeRunnable)
        Log.i(TAG, "OverlayCanvasView 생성 - Accessibility 모드")
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
                elapsed < FADE_START_MS -> 1f
                elapsed > FADE_DURATION_MS -> 0f
                else -> 1f - ((elapsed - FADE_START_MS) / (FADE_DURATION_MS - FADE_START_MS).toFloat())
            }
        }

        fun isExpired() = System.currentTimeMillis() - createdAt > FADE_DURATION_MS
    }

    /**
     * S Pen / Stylus 감지
     */
    private fun isStylus(event: MotionEvent): Boolean {
        // 방법 1: toolType 체크 (가장 정확)
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

        return false
    }

    /**
     * 터치 이벤트 처리 - 핵심 분리 로직
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val isStylus = isStylus(event)

        // 입력 모드 변경 알림
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            if (currentInputIsStylus != isStylus) {
                currentInputIsStylus = isStylus
                onInputModeChanged?.invoke(isStylus)
            }
        }

        return if (isStylus) {
            handleStylusTouch(event)
        } else {
            handleFingerTouch(event)
        }
    }

    /**
     * S Pen 터치 처리 - 캔버스에 그리기
     */
    private fun handleStylusTouch(event: MotionEvent): Boolean {
        Log.d(TAG, "✏️ S Pen: action=${event.actionMasked}, (${event.x}, ${event.y})")

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

                // 히스토리 포인트 처리 (부드러운 선)
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
                    Log.d(TAG, "스트로크 완료: 총 ${strokes.size}개")
                }
                invalidate()
                return true
            }
        }
        return true
    }

    /**
     * 손가락 터치 처리 - TouchInjectionService로 전달
     * 주입 전 FLAG_NOT_TOUCHABLE 설정하여 주입된 제스처가 다시 오버레이로 오지 않게 함
     */
    private fun handleFingerTouch(event: MotionEvent): Boolean {
        val injectionService = TouchInjectionService.instance
        val overlayService = OverlayService.instance

        if (injectionService == null) {
            Log.w(TAG, "⚠️ TouchInjectionService 없음 - 손가락 터치 무시됨")
            return false
        }

        Log.d(TAG, "👆 손가락: action=${event.actionMasked}, (${event.x}, ${event.y}) → 주입")

        // 주입 전: 오버레이를 터치 통과 상태로 변경
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            overlayService?.setPassthroughMode(true)
        }

        // 터치 이벤트를 Accessibility Service로 전달
        injectionService.injectTouchEvent(event)

        // 터치 종료 시: 오버레이 다시 터치 수신 상태로
        if (event.actionMasked == MotionEvent.ACTION_UP ||
            event.actionMasked == MotionEvent.ACTION_CANCEL) {
            // 약간의 딜레이 후 복원 (제스처 완료 대기)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                overlayService?.setPassthroughMode(false)
            }, 100)
        }

        return true
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // 저장된 스트로크 그리기
        for (stroke in strokes) {
            val opacity = stroke.getOpacity()
            if (opacity > 0) {
                paint.color = stroke.color
                paint.alpha = (opacity * 255).toInt()
                drawSegments(canvas, stroke.segments)
            }
        }

        // 현재 그리는 중인 스트로크
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

    // Public API
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
