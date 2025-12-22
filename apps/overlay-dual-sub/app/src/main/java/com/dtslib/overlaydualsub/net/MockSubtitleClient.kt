package com.dtslib.overlaydualsub.net

import android.os.Handler
import android.os.Looper
import com.dtslib.overlaydualsub.model.SubtitleEvent

class MockSubtitleClient : SubtitleStreamClient {

    private val handler = Handler(Looper.getMainLooper())
    private var segId = 0
    private var running = false
    private var delayMs = 500L
    private var onEvent: ((SubtitleEvent) -> Unit)? = null

    // Mock 데이터
    private val mockData = listOf(
        Triple("Hello, how are you today?", "안녕하세요, 오늘 기분이 어떠세요?", "Hello, how are you today?"),
        Triple("I'm working on a new project.", "새로운 프로젝트를 진행하고 있어요.", "I'm working on a new project."),
        Triple("The weather is really nice.", "날씨가 정말 좋네요.", "The weather is really nice."),
        Triple("Let me explain this concept.", "이 개념을 설명해 드릴게요.", "Let me explain this concept."),
        Triple("Thank you for listening.", "들어주셔서 감사합니다.", "Thank you for listening."),
        Triple("Do you have any questions?", "질문 있으신가요?", "Do you have any questions?"),
        Triple("This is very important.", "이것은 매우 중요합니다.", "This is very important."),
        Triple("We need to focus on results.", "결과에 집중해야 합니다.", "We need to focus on results.")
    )

    override fun start(onEvent: (SubtitleEvent) -> Unit) {
        this.onEvent = onEvent
        running = true
        segId = 0
        scheduleNext()
    }

    override fun stop() {
        running = false
        handler.removeCallbacksAndMessages(null)
    }

    override fun setDelay(ms: Long) {
        delayMs = ms
    }

    private fun scheduleNext() {
        if (!running) return

        handler.postDelayed({
            if (!running) return@postDelayed
            emitSegment()
            scheduleNext()
        }, 2500) // 2.5초마다 새 문장
    }

    private fun emitSegment() {
        val idx = segId % mockData.size
        val (dictation, ko, en) = mockData[idx]
        val currentSegId = segId
        segId++

        // 1) Dictation 먼저 (즉시)
        onEvent?.invoke(
            SubtitleEvent(
                segId = currentSegId,
                dictation = dictation,
                ko = "",
                en = ""
            )
        )

        // 2) KO 채움 (delayMs * 0.8 후)
        handler.postDelayed({
            if (!running) return@postDelayed
            onEvent?.invoke(
                SubtitleEvent(
                    segId = currentSegId,
                    dictation = dictation,
                    ko = ko,
                    en = ""
                )
            )
        }, (delayMs * 0.8).toLong())

        // 3) EN 채움 (delayMs * 1.6 후)
        handler.postDelayed({
            if (!running) return@postDelayed
            onEvent?.invoke(
                SubtitleEvent(
                    segId = currentSegId,
                    dictation = dictation,
                    ko = ko,
                    en = en
                )
            )
        }, (delayMs * 1.6).toLong())
    }
}
