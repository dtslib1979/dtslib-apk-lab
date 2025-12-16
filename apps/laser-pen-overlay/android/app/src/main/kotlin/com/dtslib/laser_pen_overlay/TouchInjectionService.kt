package com.dtslib.laser_pen_overlay

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.MotionEvent
import android.view.accessibility.AccessibilityEvent

/**
 * 손가락 터치를 아래 앱으로 주입하는 Accessibility Service
 * v21: 실시간 스트리밍 제스처로 레이턴시 최소화
 *
 * 핵심 기능:
 * 1. OverlayCanvasView에서 손가락 터치 이벤트 수신
 * 2. dispatchGesture()로 해당 터치를 시스템에 주입
 * 3. willContinue=true로 실시간 스트리밍 (API 26+)
 */
class TouchInjectionService : AccessibilityService() {

    companion object {
        private const val TAG = "TouchInjection"
        private const val STROKE_SEGMENT_DURATION = 16L  // ~60fps

        @Volatile
        var instance: TouchInjectionService? = null
            private set

        fun isRunning(): Boolean = instance != null
    }

    // 스트리밍 제스처 상태
    private var isGestureActive = false
    private var lastX = 0f
    private var lastY = 0f
    private var strokeId = 0
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "TouchInjectionService 생성")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "✅ TouchInjectionService 연결됨 - 터치 주입 준비 완료")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 이벤트 처리 불필요 - 제스처 주입만 사용
    }

    override fun onInterrupt() {
        Log.w(TAG, "TouchInjectionService 중단됨")
    }

    override fun onDestroy() {
        instance = null
        isGestureActive = false
        Log.i(TAG, "TouchInjectionService 종료")
        super.onDestroy()
    }

    /**
     * 손가락 터치 이벤트를 시스템에 즉시 주입
     * 실시간 스트리밍 방식으로 레이턴시 최소화
     */
    fun injectTouchEvent(event: MotionEvent): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            Log.w(TAG, "dispatchGesture는 API 24+ 필요")
            return false
        }

        val x = event.x
        val y = event.y

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // 즉시 시작점 주입
                dispatchSinglePoint(x, y, isStart = true, isEnd = false)
                lastX = x
                lastY = y
                isGestureActive = true
                strokeId++
            }
            MotionEvent.ACTION_MOVE -> {
                if (isGestureActive) {
                    // 이동 거리가 충분할 때만 주입 (성능 최적화)
                    val dx = x - lastX
                    val dy = y - lastY
                    if (dx * dx + dy * dy > 16) {  // 4px 이상 이동
                        dispatchSinglePoint(x, y, isStart = false, isEnd = false)
                        lastX = x
                        lastY = y
                    }
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (isGestureActive) {
                    dispatchSinglePoint(x, y, isStart = false, isEnd = true)
                    isGestureActive = false
                }
            }
        }
        return true
    }

    /**
     * 단일 포인트를 즉시 주입
     */
    private fun dispatchSinglePoint(x: Float, y: Float, isStart: Boolean, isEnd: Boolean) {
        val path = Path().apply {
            moveTo(if (isStart) x else lastX, if (isStart) y else lastY)
            lineTo(x, y)
        }

        try {
            val strokeDescription = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !isEnd) {
                // API 26+: willContinue로 연속 제스처
                GestureDescription.StrokeDescription(
                    path,
                    0,
                    STROKE_SEGMENT_DURATION,
                    true  // willContinue - 더 많은 포인트가 올 것임
                )
            } else {
                // API 24-25 또는 마지막 포인트
                GestureDescription.StrokeDescription(
                    path,
                    0,
                    if (isStart && isEnd) 50L else STROKE_SEGMENT_DURATION
                )
            }

            val gestureDescription = GestureDescription.Builder()
                .addStroke(strokeDescription)
                .build()

            dispatchGesture(gestureDescription, null, null)

        } catch (e: Exception) {
            Log.e(TAG, "포인트 주입 실패: ${e.message}")
        }
    }

    /**
     * 즉시 탭 주입 (단순 클릭용)
     */
    fun injectTap(x: Float, y: Float, callback: ((Boolean) -> Unit)? = null) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            callback?.invoke(false)
            return
        }

        val path = Path().apply {
            moveTo(x, y)
        }

        val strokeDescription = GestureDescription.StrokeDescription(
            path,
            0,
            50  // 50ms 탭
        )

        val gestureDescription = GestureDescription.Builder()
            .addStroke(strokeDescription)
            .build()

        try {
            dispatchGesture(
                gestureDescription,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        Log.d(TAG, "✅ 탭 주입 성공: ($x, $y)")
                        callback?.invoke(true)
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        Log.w(TAG, "⚠️ 탭 주입 취소됨")
                        callback?.invoke(false)
                    }
                },
                null
            )
        } catch (e: Exception) {
            Log.e(TAG, "탭 주입 실패: ${e.message}")
            callback?.invoke(false)
        }
    }

    /**
     * 스크롤 제스처 주입
     */
    fun injectScroll(
        startX: Float, startY: Float,
        endX: Float, endY: Float,
        duration: Long = 300,
        callback: ((Boolean) -> Unit)? = null
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            callback?.invoke(false)
            return
        }

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }

        val strokeDescription = GestureDescription.StrokeDescription(
            path,
            0,
            duration
        )

        val gestureDescription = GestureDescription.Builder()
            .addStroke(strokeDescription)
            .build()

        try {
            dispatchGesture(
                gestureDescription,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        Log.d(TAG, "✅ 스크롤 주입 성공")
                        callback?.invoke(true)
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        Log.w(TAG, "⚠️ 스크롤 주입 취소됨")
                        callback?.invoke(false)
                    }
                },
                null
            )
        } catch (e: Exception) {
            Log.e(TAG, "스크롤 주입 실패: ${e.message}")
            callback?.invoke(false)
        }
    }
}
