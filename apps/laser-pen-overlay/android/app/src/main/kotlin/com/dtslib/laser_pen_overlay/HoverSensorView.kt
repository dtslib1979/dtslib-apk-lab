package com.dtslib.laser_pen_overlay

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View

/**
 * S Pen 호버 감지 전용 센서 레이어
 *
 * 핵심 동작:
 * 1. S Pen 호버 감지 → onStylusNear 콜백
 * 2. S Pen 떠남 → onStylusAway 콜백
 * 3. 손가락 터치 감지 → onFingerDetected 콜백 (센서 패스스루 전환용)
 *
 * 이 뷰는 FLAG_NOT_TOUCHABLE 없이 시작하여 호버 이벤트를 받을 수 있음
 * 손가락 터치 감지 시 서비스에서 FLAG_NOT_TOUCHABLE 추가
 */
class HoverSensorView(
    context: Context,
    private val onStylusNear: () -> Unit,
    private val onStylusAway: () -> Unit,
    private val onFingerDetected: () -> Unit
) : View(context) {

    companion object {
        private const val TAG = "HoverSensor"
        private const val STYLUS_TIMEOUT_MS = 500L
    }

    private val handler = Handler(Looper.getMainLooper())
    private val stylusTimeoutRunnable = Runnable {
        Log.i(TAG, "S Pen 타임아웃 - 손가락 모드로 전환")
        isStylusActive = false
        onStylusAway()
    }

    @Volatile
    private var isStylusActive = false

    init {
        setBackgroundColor(Color.TRANSPARENT)
        isClickable = false
        isFocusable = false
        Log.i(TAG, "HoverSensorView 생성됨")
    }

    private fun isStylus(event: MotionEvent): Boolean {
        for (i in 0 until event.pointerCount) {
            when (event.getToolType(i)) {
                MotionEvent.TOOL_TYPE_STYLUS,
                MotionEvent.TOOL_TYPE_ERASER -> return true
            }
        }
        if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
            return true
        }
        return false
    }

    /**
     * 호버 이벤트 - S Pen 감지의 핵심
     */
    override fun onHoverEvent(event: MotionEvent): Boolean {
        if (isStylus(event)) {
            Log.d(TAG, "onHoverEvent: stylus, action=${event.actionMasked}")
            when (event.actionMasked) {
                MotionEvent.ACTION_HOVER_ENTER -> {
                    Log.i(TAG, ">>> S Pen HOVER ENTER")
                    activateStylus()
                }
                MotionEvent.ACTION_HOVER_MOVE -> {
                    if (!isStylusActive) {
                        Log.i(TAG, ">>> S Pen HOVER MOVE (재활성화)")
                        activateStylus()
                    }
                    resetTimeout()
                }
                MotionEvent.ACTION_HOVER_EXIT -> {
                    Log.i(TAG, ">>> S Pen HOVER EXIT")
                    startTimeout()
                }
            }
            return true
        }
        return super.onHoverEvent(event)
    }

    /**
     * 제네릭 모션 이벤트 (일부 기기 호버 대응)
     */
    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_HOVER_ENTER ||
            event.actionMasked == MotionEvent.ACTION_HOVER_MOVE) {
            if (isStylus(event) && !isStylusActive) {
                Log.i(TAG, ">>> Generic motion: S Pen 호버")
                activateStylus()
                return true
            }
        }
        return super.onGenericMotionEvent(event)
    }

    /**
     * 터치 이벤트 - 손가락 감지 시 패스스루 요청
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val stylus = isStylus(event)
        Log.d(TAG, "onTouchEvent: isStylus=$stylus, action=${event.actionMasked}")

        if (stylus) {
            // S Pen 터치 - 활성 상태 유지
            if (!isStylusActive) {
                Log.i(TAG, "S Pen 터치로 활성화")
                activateStylus()
            }
            resetTimeout()
            // 터치는 캔버스에서 처리하도록 소비하지 않음
            return false
        }

        // 손가락 터치 - 패스스루 요청
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            Log.i(TAG, ">>> 손가락 터치 감지! 패스스루 요청")
            onFingerDetected()
        }
        return false  // 터치 소비 안 함
    }

    private fun activateStylus() {
        isStylusActive = true
        handler.removeCallbacks(stylusTimeoutRunnable)
        onStylusNear()
    }

    private fun resetTimeout() {
        handler.removeCallbacks(stylusTimeoutRunnable)
        handler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
    }

    private fun startTimeout() {
        handler.removeCallbacks(stylusTimeoutRunnable)
        handler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
    }

    fun resetStylusState() {
        isStylusActive = false
        handler.removeCallbacks(stylusTimeoutRunnable)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        handler.removeCallbacks(stylusTimeoutRunnable)
    }
}
