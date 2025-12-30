package com.dtslib.overlaydualsub.net

import com.dtslib.overlaydualsub.model.SubtitleEvent

interface SubtitleStreamClient {
    fun start(onEvent: (SubtitleEvent) -> Unit)
    fun stop()
    fun setDelay(ms: Long)
}
