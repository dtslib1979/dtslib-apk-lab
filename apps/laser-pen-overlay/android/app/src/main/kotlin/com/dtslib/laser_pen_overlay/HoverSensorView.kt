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
 * 투명한 호버 센서 레이어
 *
 * 이 View는 FLAG_NOT_TOUCHABLE 없이 유지되어 항상 호버 이벤트를 수신합니다.
 * 터치 이벤트는 처리하지 않고 아래로 전달합니다.
 * S Pen 호버 감지 시 콜백을 통해 메인 캔버스의 터치 모드를 활성화합니다.
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
        private const val STYLUS_TIMEOUT_MS = 500L
        private const val FINGER_TOUCH_BLOCK_MS = 100L  // finger 터치 감지 후 센서 재활성화 딜레이
    }

    private val stylusTimeoutHandler = Handler(Looper.getMainLooper())
    private val stylusTimeoutRunnable = Runnable {
        Log.d(TAG, "Stylus timeout - notifying canvas to disable touch mode")
        isStylusActive = false
        onStylusAway()
    }

    @Volatile
    private var isStylusActive = false

    @Volatile
    private var isFingerBlocking = false

    init {
        setBackgroundColor(Color.TRANSPARENT)
        // 클릭/포커스 비활성화 - 호버만 감지
        isClickable = false
        isFocusable = false
    }

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
        // Fallback: source flag 체크
        if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
            return true
        }
        return false
    }

    /**
     * S Pen 호버 이벤트 감지 (화면에 닿기 전)
     */
    override fun onHoverEvent(event: MotionEvent): Boolean {
        if (isStylus(event)) {
            when (event.actionMasked) {
                MotionEvent.ACTION_HOVER_ENTER, MotionEvent.ACTION_HOVER_MOVE -> {
                    if (!isStylusActive) {
                        Log.d(TAG, "S Pen hover detected - enabling canvas touch mode")
                        isStylusActive = true
                        onStylusNear()
                    }
                    // 타임아웃 리셋
                    stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
                    stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
                }
                MotionEvent.ACTION_HOVER_EXIT -> {
                    Log.d(TAG, "S Pen hover exit - starting timeout")
                    stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
                    stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
                }
            }
            return true
        }
        return super.onHoverEvent(event)
    }

    /**
     * 터치 이벤트 처리
     * - stylus 터치: 캔버스 터치 모드 활성화 후 캔버스에 이벤트 전달
     * - finger 터치: 센서 일시 비활성화 요청 후 false 리턴
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (isStylus(event)) {
            // stylus 터치 시 활성 상태 유지 및 타임아웃 리셋
            if (!isStylusActive) {
                Log.d(TAG, "Stylus touch detected (no hover) - enabling canvas touch mode")
                isStylusActive = true
                onStylusNear()
            }
            stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)

            // ACTION_UP 시 타임아웃 시작
            if (event.actionMasked == MotionEvent.ACTION_UP ||
                event.actionMasked == MotionEvent.ACTION_CANCEL) {
                stylusTimeoutHandler.postDelayed(stylusTimeoutRunnable, STYLUS_TIMEOUT_MS)
            }

            // 캔버스에 이벤트 전달 (호버 없이 바로 터치한 경우 대비)
            onStylusTouchEvent?.invoke(event)
            return true  // stylus 이벤트는 소비
        }

        // finger 터치 감지 → 센서 일시 비활성화 요청
        // 이렇게 하면 후속 터치 시퀀스부터 아래 앱에 전달됨
        if (event.actionMasked == MotionEvent.ACTION_DOWN && !isFingerBlocking) {
            Log.d(TAG, "Finger touch detected - requesting sensor disable for pass-through")
            isFingerBlocking = true
            onFingerTouchDetected?.invoke()
        }

        // finger 터치는 처리하지 않음
        return false
    }

    fun resetStylusState() {
        isStylusActive = false
        isFingerBlocking = false
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
    }

    fun clearFingerBlock() {
        isFingerBlocking = false
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stylusTimeoutHandler.removeCallbacks(stylusTimeoutRunnable)
    }
}
