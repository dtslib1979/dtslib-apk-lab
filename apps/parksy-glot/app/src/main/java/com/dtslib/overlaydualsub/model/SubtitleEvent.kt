package com.dtslib.overlaydualsub.model

data class SubtitleEvent(
    val segId: Int,
    val dictation: String = "",
    val ko: String = "",
    val en: String = ""
)
