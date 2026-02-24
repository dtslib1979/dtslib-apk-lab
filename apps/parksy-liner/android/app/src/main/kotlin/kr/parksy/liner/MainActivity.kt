package kr.parksy.liner

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.*
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.math.*

class MainActivity : FlutterActivity() {
    private val ENGINE_CHANNEL = "kr.parksy.liner/engine"
    private val NOTES_CHANNEL = "kr.parksy.liner/notes"

    // Canvas spec
    private val CANVAS_W = 2160
    private val CANVAS_H = 3060

    // Line/Shade colors
    private val LINE_R = 0xC3; private val LINE_G = 0xC3; private val LINE_B = 0xC3
    private val LINE_ALPHA_MIN = (255 * 0.70).toInt()
    private val LINE_ALPHA_MAX = (255 * 0.85).toInt()
    private val SHADE_R = 0xC8; private val SHADE_G = 0xC8; private val SHADE_B = 0xC8
    private val SHADE_ALPHA_MIN = (255 * 0.25).toInt()
    private val SHADE_ALPHA_MAX = (255 * 0.45).toInt()

    // XDoG params
    private val XDOG_SIGMA = 0.5f
    private val XDOG_K = 1.6f
    private val XDOG_EPSILON = 0.01f
    private val XDOG_PHI = 10.0f

    private val SAMSUNG_NOTES_PKG = "com.samsung.android.app.notes"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Engine channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ENGINE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "processImage" -> {
                        val inputPath = call.argument<String>("inputPath")!!
                        val outputDir = call.argument<String>("outputDir")
                            ?: filesDir.absolutePath + "/liner_output"
                        Thread {
                            try {
                                val paths = processImage(inputPath, outputDir)
                                runOnUiThread { result.success(paths) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("PROCESS_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        // Notes bridge channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openInNotes" -> {
                        val path = call.argument<String>("imagePath")!!
                        result.success(openInSamsungNotes(path))
                    }
                    "isSamsungNotesAvailable" -> {
                        result.success(isPackageInstalled(SAMSUNG_NOTES_PKG))
                    }
                    "shareImage" -> {
                        val path = call.argument<String>("imagePath")!!
                        shareImage(path)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ═══════════════════════════════════════════════════
    // Image Processing Pipeline
    // ═══════════════════════════════════════════════════

    private fun processImage(inputPath: String, outputDir: String): Map<String, String> {
        File(outputDir).mkdirs()
        val nameNoExt = File(inputPath).nameWithoutExtension

        // 1. Decode + letterbox
        val original = BitmapFactory.decodeFile(inputPath)
            ?: throw Exception("Cannot decode: $inputPath")

        val canvas = letterboxFit(original)
        original.recycle()

        // 2. Grayscale
        val w = canvas.width
        val h = canvas.height
        val pixels = IntArray(w * h)
        canvas.getPixels(pixels, 0, w, 0, 0, w, h)

        val gray = FloatArray(w * h)
        for (i in pixels.indices) {
            val c = pixels[i]
            val r = (c shr 16) and 0xFF
            val g = (c shr 8) and 0xFF
            val b = c and 0xFF
            gray[i] = (0.2989f * r + 0.5870f * g + 0.1140f * b) / 255f
        }

        // 3. XDoG edge detection
        val edgeMap = xdogEdge(gray, w, h)

        // 4. Shade extraction
        val shadeMap = extractShade(gray, w, h)

        // 5. Build output bitmaps
        val lineBmp = buildLineRgba(edgeMap, w, h)
        val shadeBmp = buildShadeRgba(shadeMap, w, h)
        val comboBmp = buildCombo(lineBmp, shadeBmp, w, h)

        // 6. Save
        val paths = mutableMapOf<String, String>()

        val linePath = "$outputDir/${nameNoExt}_line_rgba.png"
        savePng(lineBmp, linePath)
        paths["line"] = linePath

        val shadePath = "$outputDir/${nameNoExt}_shade_rgba.png"
        savePng(shadeBmp, shadePath)
        paths["shade"] = shadePath

        val comboPath = "$outputDir/${nameNoExt}_combo_for_notes.png"
        savePng(comboBmp, comboPath)
        paths["combo"] = comboPath

        // Preview: just save combo as preview (skip 4-panel for perf)
        val previewPath = "$outputDir/${nameNoExt}_preview_debug.png"
        savePng(comboBmp, previewPath)
        paths["preview"] = previewPath

        // Cleanup
        canvas.recycle()
        lineBmp.recycle()
        shadeBmp.recycle()
        comboBmp.recycle()

        return paths
    }

    private fun letterboxFit(src: Bitmap): Bitmap {
        val scaleW = CANVAS_W.toFloat() / src.width
        val scaleH = CANVAS_H.toFloat() / src.height
        val scale = minOf(scaleW, scaleH)

        val nw = (src.width * scale).toInt()
        val nh = (src.height * scale).toInt()

        val resized = Bitmap.createScaledBitmap(src, nw, nh, true)
        val canvas = Bitmap.createBitmap(CANVAS_W, CANVAS_H, Bitmap.Config.ARGB_8888)
        val c = Canvas(canvas)
        c.drawColor(Color.BLACK)

        val ox = (CANVAS_W - nw) / 2f
        val oy = (CANVAS_H - nh) / 2f
        c.drawBitmap(resized, ox, oy, null)
        resized.recycle()

        return canvas
    }

    // ═══════════════════════════════════════════════════
    // XDoG
    // ═══════════════════════════════════════════════════

    private fun xdogEdge(gray: FloatArray, w: Int, h: Int): FloatArray {
        val g1 = gaussianBlur(gray, w, h, XDOG_SIGMA)
        val g2 = gaussianBlur(gray, w, h, XDOG_SIGMA * XDOG_K)

        val result = FloatArray(w * h)
        for (i in result.indices) {
            val dog = g1[i] - g2[i]
            result[i] = if (dog >= XDOG_EPSILON) {
                1f
            } else {
                (1f + tanh(XDOG_PHI * (dog - XDOG_EPSILON))).coerceIn(0f, 1f)
            }
        }
        return result
    }

    private fun gaussianBlur(src: FloatArray, w: Int, h: Int, sigma: Float): FloatArray {
        if (sigma < 0.3f) return src.clone()

        val radius = ceil(sigma * 3).toInt().coerceAtLeast(1)
        val kernel = FloatArray(radius * 2 + 1)
        var sum = 0f
        for (i in kernel.indices) {
            val x = (i - radius).toFloat()
            kernel[i] = exp(-x * x / (2f * sigma * sigma))
            sum += kernel[i]
        }
        for (i in kernel.indices) kernel[i] /= sum

        // Horizontal pass
        val temp = FloatArray(w * h)
        for (y in 0 until h) {
            for (x in 0 until w) {
                var v = 0f
                for (k in kernel.indices) {
                    val sx = (x + k - radius).coerceIn(0, w - 1)
                    v += src[y * w + sx] * kernel[k]
                }
                temp[y * w + x] = v
            }
        }

        // Vertical pass
        val out = FloatArray(w * h)
        for (y in 0 until h) {
            for (x in 0 until w) {
                var v = 0f
                for (k in kernel.indices) {
                    val sy = (y + k - radius).coerceIn(0, h - 1)
                    v += temp[sy * w + x] * kernel[k]
                }
                out[y * w + x] = v
            }
        }
        return out
    }

    // ═══════════════════════════════════════════════════
    // Shade
    // ═══════════════════════════════════════════════════

    private fun extractShade(gray: FloatArray, w: Int, h: Int): FloatArray {
        val inverted = FloatArray(gray.size) { 1f - gray[it] }
        val blurred = gaussianBlur(inverted, w, h, 8f)

        var smin = Float.MAX_VALUE
        var smax = Float.MIN_VALUE
        for (v in blurred) { smin = minOf(smin, v); smax = maxOf(smax, v) }

        val range = smax - smin
        return if (range > 0.01f) {
            FloatArray(blurred.size) {
                val n = (blurred[it] - smin) / range
                if (n > 0.2f) n else 0f
            }
        } else {
            FloatArray(blurred.size)
        }
    }

    // ═══════════════════════════════════════════════════
    // Build output bitmaps
    // ═══════════════════════════════════════════════════

    private fun buildLineRgba(edgeMap: FloatArray, w: Int, h: Int): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(w * h)
        for (i in edgeMap.indices) {
            val strength = 1f - edgeMap[i]
            if (strength > 0.1f) {
                val alpha = (strength * (LINE_ALPHA_MAX - LINE_ALPHA_MIN) + LINE_ALPHA_MIN)
                    .toInt().coerceIn(0, 255)
                pixels[i] = Color.argb(alpha, LINE_R, LINE_G, LINE_B)
            }
        }
        bmp.setPixels(pixels, 0, w, 0, 0, w, h)
        return bmp
    }

    private fun buildShadeRgba(shadeMap: FloatArray, w: Int, h: Int): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(w * h)
        for (i in shadeMap.indices) {
            if (shadeMap[i] > 0.05f) {
                val alpha = (shadeMap[i] * (SHADE_ALPHA_MAX - SHADE_ALPHA_MIN) + SHADE_ALPHA_MIN)
                    .toInt().coerceIn(0, 255)
                pixels[i] = Color.argb(alpha, SHADE_R, SHADE_G, SHADE_B)
            }
        }
        bmp.setPixels(pixels, 0, w, 0, 0, w, h)
        return bmp
    }

    private fun buildCombo(lineBmp: Bitmap, shadeBmp: Bitmap, w: Int, h: Int): Bitmap {
        val combo = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(combo)
        canvas.drawColor(Color.WHITE)

        val paint = Paint().apply { isAntiAlias = true }
        canvas.drawBitmap(shadeBmp, 0f, 0f, paint)
        canvas.drawBitmap(lineBmp, 0f, 0f, paint)

        return combo
    }

    private fun savePng(bmp: Bitmap, path: String) {
        FileOutputStream(path).use { fos ->
            bmp.compress(Bitmap.CompressFormat.PNG, 100, fos)
        }
    }

    // ═══════════════════════════════════════════════════
    // Samsung Notes Bridge
    // ═══════════════════════════════════════════════════

    private fun openInSamsungNotes(imagePath: String): Boolean {
        val file = File(imagePath)
        if (!file.exists()) return false

        val uri = FileProvider.getUriForFile(
            this,
            "kr.parksy.liner.fileprovider",
            file
        )

        // Try Samsung Notes directly
        if (isPackageInstalled(SAMSUNG_NOTES_PKG)) {
            try {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    setPackage(SAMSUNG_NOTES_PKG)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {}
        }

        // Fallback: chooser
        shareImage(imagePath)
        return false
    }

    private fun shareImage(imagePath: String) {
        val file = File(imagePath)
        if (!file.exists()) return

        val uri = FileProvider.getUriForFile(
            this,
            "kr.parksy.liner.fileprovider",
            file
        )

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share sketch"))
    }

    private fun isPackageInstalled(pkg: String): Boolean {
        return try {
            packageManager.getPackageInfo(pkg, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
