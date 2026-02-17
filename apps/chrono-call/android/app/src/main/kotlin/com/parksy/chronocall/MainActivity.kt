package com.parksy.chronocall

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.parksy.chronocall/intent"
    private var pendingAudioPath: String? = null
    private var pendingAudioName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Process intent immediately on engine config
        processIncomingIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedAudio" -> {
                    if (pendingAudioPath != null) {
                        result.success(mapOf(
                            "path" to pendingAudioPath,
                            "name" to (pendingAudioName ?: "shared_audio")
                        ))
                        // Clear after consumption
                        pendingAudioPath = null
                        pendingAudioName = null
                    } else {
                        result.success(null)
                    }
                }
                "copyUriToLocal" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString != null) {
                        val copied = copyContentUriToLocal(Uri.parse(uriString))
                        result.success(copied)
                    } else {
                        result.error("INVALID_ARG", "uri is required", null)
                    }
                }
                "getAudioMetadata" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val file = File(path)
                        result.success(mapOf(
                            "exists" to file.exists(),
                            "sizeBytes" to file.length(),
                            "sizeMB" to String.format("%.1f", file.length() / (1024.0 * 1024.0)),
                            "lastModified" to file.lastModified(),
                            "name" to file.name
                        ))
                    } else {
                        result.error("INVALID_ARG", "path is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        processIncomingIntent(intent)
    }

    private fun processIncomingIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_SEND) return

        val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

        if (uri == null) return

        // content:// URIs can't be used directly by FFmpeg.
        // Copy to app's cache directory as a real file.
        val result = copyContentUriToLocal(uri)
        if (result != null) {
            pendingAudioPath = result["path"] as? String
            pendingAudioName = result["name"] as? String
        }
    }

    /**
     * Copy a content:// URI to local cache dir.
     * Returns map with "path" and "name", or null on failure.
     * FFmpeg requires real file paths, not content:// URIs.
     */
    private fun copyContentUriToLocal(uri: Uri): Map<String, String>? {
        try {
            val displayName = getDisplayName(uri) ?: "audio_${System.currentTimeMillis()}"
            val cacheDir = File(cacheDir, "chrono_imports")
            if (!cacheDir.exists()) cacheDir.mkdirs()

            val destFile = File(cacheDir, displayName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output, bufferSize = 8192)
                }
            } ?: return null

            return mapOf(
                "path" to destFile.absolutePath,
                "name" to displayName
            )
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    /**
     * Extract display name from content:// URI via ContentResolver.
     */
    private fun getDisplayName(uri: Uri): String? {
        var name: String? = null
        val cursor: Cursor? = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val idx = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) {
                    name = it.getString(idx)
                }
            }
        }
        // Fallback: extract from URI path
        if (name == null) {
            name = uri.lastPathSegment
        }
        return name
    }
}
