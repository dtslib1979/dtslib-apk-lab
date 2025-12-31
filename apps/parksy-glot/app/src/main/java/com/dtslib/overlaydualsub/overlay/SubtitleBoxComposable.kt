package com.dtslib.overlaydualsub.overlay

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dtslib.overlaydualsub.model.OverlaySettings
import com.dtslib.overlaydualsub.model.SubtitleEvent

@Composable
fun SubtitleBoxComposable(
    subtitle: SubtitleEvent,
    settings: OverlaySettings,
    visible: Boolean,
    onDrag: (Float, Float) -> Unit
) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(),
        exit = fadeOut()
    ) {
        Column(
            modifier = Modifier
                .alpha(settings.opacity)
                .background(
                    color = Color.Black.copy(alpha = 0.7f),
                    shape = RoundedCornerShape(8.dp)
                )
                .padding(12.dp)
                .pointerInput(Unit) {
                    detectDragGestures { change, dragAmount ->
                        change.consume()
                        onDrag(dragAmount.x, dragAmount.y)
                    }
                }
        ) {
            // Dictation (optional)
            if (settings.showDictation) {
                SubtitleLine(
                    label = "DICT",
                    text = subtitle.dictation.ifEmpty { "\u2026" },
                    color = Color.Gray,
                    fontSize = settings.fontSize * 0.85f
                )
                Spacer(Modifier.height(4.dp))
            }

            // KO line
            SubtitleLine(
                label = "KO",
                text = subtitle.ko.ifEmpty { "\u2026" },
                color = Color(0xFFFFEB3B),
                fontSize = settings.fontSize
            )

            Spacer(Modifier.height(4.dp))

            // EN line
            SubtitleLine(
                label = "EN",
                text = subtitle.en.ifEmpty { "\u2026" },
                color = Color.White,
                fontSize = settings.fontSize
            )
        }
    }
}

@Composable
private fun SubtitleLine(
    label: String,
    text: String,
    color: Color,
    fontSize: Float
) {
    Row {
        Text(
            text = "$label ",
            color = color.copy(alpha = 0.6f),
            fontSize = (fontSize * 0.7f).sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = text,
            color = color,
            fontSize = fontSize.sp
        )
    }
}
