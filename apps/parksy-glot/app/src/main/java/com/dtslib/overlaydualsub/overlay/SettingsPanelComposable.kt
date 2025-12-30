package com.dtslib.overlaydualsub.overlay

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dtslib.overlaydualsub.model.OverlaySettings

@Composable
fun SettingsPanelComposable(
    settings: OverlaySettings,
    onUpdate: (OverlaySettings) -> Unit,
    onClose: () -> Unit
) {
    Column(
        modifier = Modifier
            .background(
                color = Color.Black.copy(alpha = 0.9f),
                shape = RoundedCornerShape(12.dp)
            )
            .padding(16.dp)
            .width(280.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Settings",
                color = Color.White,
                fontSize = 18.sp
            )
            TextButton(onClick = onClose) {
                Text("X", color = Color.White)
            }
        }

        Spacer(Modifier.height(16.dp))

        // Font Size: 12 ~ 28
        SliderRow(
            label = "Font Size",
            value = settings.fontSize,
            range = 12f..28f,
            display = "${settings.fontSize.toInt()}sp"
        ) { onUpdate(settings.copy(fontSize = it)) }

        Spacer(Modifier.height(12.dp))

        // Opacity: 0.3 ~ 1.0
        SliderRow(
            label = "Opacity",
            value = settings.opacity,
            range = 0.3f..1f,
            display = "${(settings.opacity * 100).toInt()}%"
        ) { onUpdate(settings.copy(opacity = it)) }

        Spacer(Modifier.height(12.dp))

        // Width: 0.5 ~ 1.0
        SliderRow(
            label = "Width",
            value = settings.boxWidth,
            range = 0.5f..1f,
            display = "${(settings.boxWidth * 100).toInt()}%"
        ) { onUpdate(settings.copy(boxWidth = it)) }

        Spacer(Modifier.height(12.dp))

        // Delay: 0 ~ 1500ms
        SliderRow(
            label = "Delay",
            value = settings.delayMs.toFloat(),
            range = 0f..1500f,
            display = "${settings.delayMs}ms"
        ) { onUpdate(settings.copy(delayMs = it.toLong())) }

        Spacer(Modifier.height(16.dp))

        // Show Dictation Toggle
        ToggleRow(
            label = "Show Dictation",
            checked = settings.showDictation
        ) { onUpdate(settings.copy(showDictation = it)) }

        Spacer(Modifier.height(8.dp))

        // Position Lock Toggle
        ToggleRow(
            label = "Lock Position",
            checked = settings.positionLocked
        ) { onUpdate(settings.copy(positionLocked = it)) }
    }
}

@Composable
private fun SliderRow(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    display: String,
    onChange: (Float) -> Unit
) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(label, color = Color.White, fontSize = 14.sp)
            Text(display, color = Color.Gray, fontSize = 14.sp)
        }
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            colors = SliderDefaults.colors(
                thumbColor = Color(0xFF90CAF9),
                activeTrackColor = Color(0xFF1976D2)
            )
        )
    }
}

@Composable
private fun ToggleRow(
    label: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, color = Color.White, fontSize = 14.sp)
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color(0xFF90CAF9),
                checkedTrackColor = Color(0xFF1976D2)
            )
        )
    }
}
