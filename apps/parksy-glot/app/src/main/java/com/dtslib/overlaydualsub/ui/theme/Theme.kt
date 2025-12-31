package com.dtslib.overlaydualsub.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColors = darkColorScheme(
    primary = Color(0xFF90CAF9),
    secondary = Color(0xFF80DEEA),
    background = Color(0xFF121212),
    surface = Color(0xFF1E1E1E)
)

private val LightColors = lightColorScheme(
    primary = Color(0xFF1976D2),
    secondary = Color(0xFF00ACC1),
    background = Color(0xFFFAFAFA),
    surface = Color(0xFFFFFFFF)
)

@Composable
fun OverlayDualSubTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) DarkColors else LightColors
    val view = LocalView.current

    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colors.background.toArgb()
            WindowCompat.getInsetsController(window, view)
                .isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colors,
        typography = Typography(),
        content = content
    )
}
