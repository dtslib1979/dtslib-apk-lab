package com.dtslib.laser_pen_overlay

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.util.Log
import android.view.MotionEvent
import android.view.accessibility.AccessibilityEvent
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * 손가락 터치를 아래 앱으로 주입하는 Accessibility Service
 *
 * 핵심 기능:
 * 1. OverlayCanvasView에서 손가락 터치 이벤트 수신
 * 2. dispatchGesture()로 해당 터치를 시스템에 주입
 * 3. 주입된 터치는 오버레이 아래 앱에서 처리됨
 */
class TouchInjectionService : AccessibilityService() {

    companion object {
        private const val TAG = "TouchInjection"

        @Volatile
        var instance: TouchInjectionService? = null
            private set

        fun isRunning(): Boolean = instance != null
    }

    // 진행 중인 제스처 추적
    private data class GestureState(
        val path: Path,
        var lastX: Float,
        var lastY: Float,
        val startTime: Long
    )

    private var currentGesture: GestureState? = null
    private val pendingMoves = ConcurrentLinkedQueue<Pair<Float, Float>>()

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
        currentGesture = null
        Log.i(TAG, "TouchInjectionService 종료")
        super.onDestroy()
    }

    /**
     * 손가락 터치 이벤트를 시스템에 주입
     * OverlayCanvasView에서 호출됨
     */
    fun injectTouchEvent(event: MotionEvent): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            Log.w(TAG, "dispatchGesture는 API 24+ 필요")
            return false
        }

        return when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                startGesture(event.x, event.y)
                true
            }
            MotionEvent.ACTION_MOVE -> {
                continueGesture(event.x, event.y)
                true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                endGesture(event.x, event.y)
                true
            }
            else -> false
        }
    }

    /**
     * 제스처 시작 (ACTION_DOWN)
     */
    private fun startGesture(x: Float, y: Float) {
        val path = Path().apply {
            moveTo(x, y)
        }

        currentGesture = GestureState(
            path = path,
            lastX = x,
            lastY = y,
            startTime = System.currentTimeMillis()
        )

        Log.d(TAG, "제스처 시작: ($x, $y)")
    }

    /**
     * 제스처 계속 (ACTION_MOVE)
     */
    private fun continueGesture(x: Float, y: Float) {
        currentGesture?.let { gesture ->
            gesture.path.lineTo(x, y)
            gesture.lastX = x
            gesture.lastY = y
        }
    }

    /**
     * 제스처 종료 및 디스패치 (ACTION_UP)
     */
    private fun endGesture(x: Float, y: Float) {
        val gesture = currentGesture ?: return
        currentGesture = null

        gesture.path.lineTo(x, y)

        val duration = System.currentTimeMillis() - gesture.startTime
        val gestureDuration = duration.coerceIn(50, 1000)

        try {
            val strokeDescription = GestureDescription.StrokeDescription(
                gesture.path,
                0,  // startTime
                gestureDuration
            )

            val gestureDescription = GestureDescription.Builder()
                .addStroke(strokeDescription)
                .build()

            val result = dispatchGesture(
                gestureDescription,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        Log.d(TAG, "✅ 제스처 주입 성공")
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        Log.w(TAG, "⚠️ 제스처 주입 취소됨")
                    }
                },
                null
            )

            Log.d(TAG, "제스처 디스패치: result=$result, duration=${gestureDuration}ms")

        } catch (e: Exception) {
            Log.e(TAG, "제스처 디스패치 실패: ${e.message}")
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
