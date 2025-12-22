package com.dtslib.overlaydualsub.overlay

import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.dtslib.overlaydualsub.model.OverlaySettings
import com.dtslib.overlaydualsub.model.SubtitleEvent

class OverlayWindowController(
    private val context: Context
) : LifecycleOwner, SavedStateRegistryOwner {

    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    // Lifecycle
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateCtrl = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateCtrl.savedStateRegistry

    // State
    val settings = mutableStateOf(OverlaySettings())
    val subtitle = mutableStateOf(SubtitleEvent(segId = 0))
    val showBox = mutableStateOf(true)
    val showSettings = mutableStateOf(false)

    // Views
    private var bubbleView: ComposeView? = null
    private var boxView: ComposeView? = null
    private var settingsView: ComposeView? = null

    // Position
    private var bubbleX = 50
    private var bubbleY = 200
    private var boxX = 0
    private var boxY = 400

    fun show() {
        savedStateCtrl.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
        showBubble()
        showSubtitleBox()
    }

    fun hide() {
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        bubbleView?.let { wm.removeView(it) }
        boxView?.let { wm.removeView(it) }
        settingsView?.let { wm.removeView(it) }
        bubbleView = null
        boxView = null
        settingsView = null
    }

    fun updateSubtitle(event: SubtitleEvent) {
        subtitle.value = event
    }

    fun toggleBox() {
        showBox.value = !showBox.value
    }

    fun toggleSettings() {
        if (showSettings.value) {
            hideSettingsPanel()
        } else {
            showSettingsPanel()
        }
        showSettings.value = !showSettings.value
    }

    private fun showBubble() {
        val view = ComposeView(context).apply {
            setViewTreeLifecycleOwner(this@OverlayWindowController)
            setViewTreeSavedStateRegistryOwner(this@OverlayWindowController)
            setContent {
                BubbleComposable(
                    onTap = { toggleBox() },
                    onLongPress = { toggleSettings() },
                    onDrag = { dx, dy -> moveBubble(dx, dy) }
                )
            }
        }
        bubbleView = view

        val params = bubbleParams()
        params.x = bubbleX
        params.y = bubbleY
        wm.addView(view, params)
    }

    private fun showSubtitleBox() {
        val view = ComposeView(context).apply {
            setViewTreeLifecycleOwner(this@OverlayWindowController)
            setViewTreeSavedStateRegistryOwner(this@OverlayWindowController)
            setContent {
                SubtitleBoxComposable(
                    subtitle = subtitle.value,
                    settings = settings.value,
                    visible = showBox.value,
                    onDrag = { dx, dy -> moveBox(dx, dy) }
                )
            }
        }
        boxView = view

        val params = boxParams()
        params.x = boxX
        params.y = boxY
        wm.addView(view, params)
    }

    private fun showSettingsPanel() {
        val view = ComposeView(context).apply {
            setViewTreeLifecycleOwner(this@OverlayWindowController)
            setViewTreeSavedStateRegistryOwner(this@OverlayWindowController)
            setContent {
                SettingsPanelComposable(
                    settings = settings.value,
                    onUpdate = { newSettings ->
                        settings.value = newSettings
                        refreshBoxWidth()
                    },
                    onClose = { toggleSettings() }
                )
            }
        }
        settingsView = view

        val params = settingsParams()
        wm.addView(view, params)
    }

    private fun hideSettingsPanel() {
        settingsView?.let { wm.removeView(it) }
        settingsView = null
    }

    private fun refreshBoxWidth() {
        boxView?.let {
            val p = it.layoutParams as WindowManager.LayoutParams
            p.width = (context.resources.displayMetrics.widthPixels * settings.value.boxWidth).toInt()
            wm.updateViewLayout(it, p)
        }
    }

    private fun moveBubble(dx: Float, dy: Float) {
        bubbleX += dx.toInt()
        bubbleY += dy.toInt()
        bubbleView?.let {
            val p = it.layoutParams as WindowManager.LayoutParams
            p.x = bubbleX
            p.y = bubbleY
            wm.updateViewLayout(it, p)
        }
    }

    private fun moveBox(dx: Float, dy: Float) {
        if (settings.value.positionLocked) return
        boxX += dx.toInt()
        boxY += dy.toInt()
        boxView?.let {
            val p = it.layoutParams as WindowManager.LayoutParams
            p.x = boxX
            p.y = boxY
            wm.updateViewLayout(it, p)
        }
    }

    private fun bubbleParams() = WindowManager.LayoutParams(
        dpToPx(48),
        dpToPx(48),
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
    }

    private fun boxParams(): WindowManager.LayoutParams {
        val w = (context.resources.displayMetrics.widthPixels * settings.value.boxWidth).toInt()
        return WindowManager.LayoutParams(
            w,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
    }

    private fun settingsParams() = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.CENTER
    }

    private fun dpToPx(dp: Int): Int {
        val density = context.resources.displayMetrics.density
        return (dp * density).toInt()
    }
}
