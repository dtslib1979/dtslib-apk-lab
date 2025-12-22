package com.dtslib.overlaydualsub.model

data class OverlaySettings(
    val fontSize: Float = 18f,        // sp
    val opacity: Float = 0.85f,       // 0.0 ~ 1.0
    val boxWidth: Float = 0.9f,       // 화면 비율 (0.5 ~ 1.0)
    val showDictation: Boolean = false,
    val delayMs: Long = 500L,         // KO→EN 딜레이
    val positionLocked: Boolean = false
)
