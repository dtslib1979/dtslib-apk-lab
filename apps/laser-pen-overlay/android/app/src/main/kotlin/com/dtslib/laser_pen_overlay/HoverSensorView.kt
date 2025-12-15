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
 * 투명한 호버 센서 레이어 (개선 버전)
 *
 * 핵심 변경점:
 * - 이 View는 오직 S Pen 호버 이벤트만 감지
 * - 터치 이벤트는 절대 소비하지 않음 (항상 아래로 전달)
 * - S Pen 호버 감지 시 캔버스의 터치 모드를 활성화
 * - S Pen이 멀어지면 캔버스 터치 모드 비활성화 → 손가락 터치 통과
 */
class HoverSensorView(
    context: Context,
    private val onStylusNear: () -> Unit,
    private val onStylusAway: () -> Unit,
    private val onStylusTouchEvent: ((MotionEvent) -> Boolean)? = null,
    private val onFingerTouchDetected: (() -> Unit)? = null
) : View(context) {

    companion object {
        private const val TAG = "HoverSensorView"
        private const val STYLUS_TIMEOUT_MS = 800L  // 타임아웃 약간 늘림
    }

    private val stylusTimeoutHandler = Handler(Looper.getMainLooper())
    private val stylusTimeoutRunnable = Runnable {
        Log.d(TAG, "Stylus timeout - disabling canvas touch mode for finger pass-through")
        isStylusActive = false
        onStylusAway()
    }

    @Volatile
    private var isStylusActive = false

    init {
        setBackgroundColor(Color.TRANSPARENT)
        isClickable = false
        isFocusable = false
    }

    /**
     * S Pen / Stylus 감지 (toolType 기반)
     */
    private fun isStylus(event: MotionEvent): Boolean {
        for (i in 0 until event.pointerCount) {
            val toolType = event.getToolType(i)
            if (toolType == MotionEvent.TOOL_TYPE_STYLUS ||
                toolType == MotionEvent.TOOL_TYPE_ERASER) {
                return true
            }
        }
        // Fallback: source flag 체크 (일부 구형 기기 대응)
        if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
            return true
        }
        return false
    }

    /**
     * S Pen 호버 이벤트 감지 (화면에 닿기 전)
     * 이 메서드가 핵심! S Pen이 가까이 오면 캔버스 터치 모드 활성화
     */
    override fun onHoverEvent(event: MotionEvent): Boolean {
        if (isStylus(event)) {
            when (event.actionMasked) {
                MotionEvent.ACTION_HOVER_ENTER -> {
                    Log.d(TAG, "S Pen hover ENTER - enabling canvas touch mode")
                    activateStylus()
                }
                MotionEvent.ACTION_HOVER_MOVE -> {
                    if (!isStylusActive) {
                        Log.d(TAG, "S Pen hover MOVE (was inactive) - enabling canvas touch mode")
                        activateStylus()
                    } else {
                        // 타임아웃만 리셋
                        resetStylusTimeout()
                    }
                }
                MotionEvent.ACTION_HOVER_EXIT -> {
                    Log.d(TAG, "S Pen hover EXIT - starting timeout")
                    startStylusTimeout()
                }
            }
            return true  // 호버 이벤트는 소비 (아래로 전달 불필요)
        }
        return super.onHoverEvent(event)
    }

    /**
     * 터치 이벤트 처리
     *
     * 중요: 이 센서 레이어는 FLAG_NOT_TOUCHABLE로 설정되어 있어서
     * 일반적으로 터치 이벤트를 받지 않음.
     * 하지만 S Pen 터치는 호버 없이도 바로 터치할 수 있으므로 대비.
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // S Pen 터치인 경우
        if (isStylus(event)) {
            Log.d(TAG, "Stylus TOUCH event: action=${event.actionMasked}")

            // 호버 없이 바로 터치한 경우 대비
            if (!isStylusActive) {
                Log.d(TAG, "Stylus touch without hover - activating")
                activateStylus()
            } else {
                resetStylusTimeout()
            }

            // ACTION_UP/CANCEL 시 타임아웃 시작
            if (event.actionMasked == MotionEvent.ACTION_UP ||
                event.actionMasked == MotionEvent.ACTION_CANCEL) {
                startStylusTimeout()
            }

            // 캔버스에 이벤트 전달
            val consumed = onStylusTouchEvent?.invoke(event) ?: false
            return consumed
        }

        // 손가락 터치: 절대 소비하지 않음 → 아래 앱으로 전달
        Log.v(TAG, "Finger touch - NOT consuming, passing through")
        return false
    }

    /**
     * 제네릭 모션 이벤트 (추가 호버 감지)
     */
    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_HOVER_MOVE ||
            event.action == MotionEvent.ACTION_HOVER_ENTER) {
            if (isStylus(event) && !isStylusActive) {
                Log.d(TAG, "Generic motion: S Pen detected")
                activateStylus()
                return true
            }
        }
        return super.onGenericMotionEvent(event)
    }

    private fun activateStylus() {
        isStylusActive = true
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
        onStylusNear()
    }

    private fun resetStylusTimeout() {
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
        stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
    }

    private fun startStylusTimeout() {
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
        stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
    }

    fun resetStylusState() {
        isStylusActive = false
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
    }

    fun clearFingerBlock() {
        // 더 이상 finger blocking 로직 사용 안 함
    }

    fun isStylusCurrentlyActive(): Boolean = isStylusActive

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
    }
}
