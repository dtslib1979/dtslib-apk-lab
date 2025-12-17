package com.parksy.capture

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.parksy.capture/share"
    private var sharedText: String? = null
    private var isShareIntent: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                if ("text/plain" == intent.type) {
                    sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    isShareIntent = true
                }
            }
            Intent.ACTION_PROCESS_TEXT -> {
                sharedText = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                isShareIntent = true
            }
            else -> {
                isShareIntent = false
            }
        }
        // Fallback: try clipData if still null
        if (isShareIntent && sharedText.isNullOrEmpty()) {
            sharedText = intent?.clipData?.getItemAt(0)?.coerceToText(this)?.toString()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isShareIntent" -> {
                        result.success(isShareIntent)
                    }
                    "getSharedText" -> {
                        result.success(sharedText)
                    }
                    "saveToDownloads" -> {
                        val filename = call.argument<String>("filename") ?: ""
                        val content = call.argument<String>("content") ?: ""
                        val success = saveFile(filename, content)
                        result.success(success)
                    }
                    "getLogFiles" -> {
                        val files = getLogFiles()
                        result.success(files)
                    }
                    "readLogFile" -> {
                        val filename = call.argument<String>("filename") ?: ""
                        val content = readLogFile(filename)
                        result.success(content)
                    }
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val title = call.argument<String>("title") ?: "Share"
                        shareText(text, title)
                        result.success(true)
                    }
                    "deleteLogFile" -> {
                        val filename = call.argument<String>("filename") ?: ""
                        val success = deleteLogFile(filename)
                        result.success(success)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getLogsDir(): File {
        return File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            ), "parksy-logs"
        )
    }

    private fun getLogFiles(): List<Map<String, Any>> {
        val dir = getLogsDir()
        if (!dir.exists()) return emptyList()
        
        return dir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".md") }
            ?.sortedByDescending { it.lastModified() }
            ?.map { file ->
                mapOf(
                    "name" to file.name,
                    "size" to file.length(),
                    "modified" to file.lastModified()
                )
            } ?: emptyList()
    }

    private fun readLogFile(filename: String): String? {
        return try {
            val file = File(getLogsDir(), filename)
            if (file.exists()) file.readText() else null
        } catch (e: Exception) {
            null
        }
    }

    private fun deleteLogFile(filename: String): Boolean {
        return try {
            val file = File(getLogsDir(), filename)
            if (file.exists()) file.delete() else false
        } catch (e: Exception) {
            false
        }
    }

    private fun shareText(text: String, title: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(intent, title))
    }

    private fun saveFile(filename: String, content: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ : MediaStore API
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, filename)
                    put(MediaStore.Downloads.MIME_TYPE, "text/markdown")
                    put(MediaStore.Downloads.RELATIVE_PATH, 
                        Environment.DIRECTORY_DOWNLOADS + "/parksy-logs")
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                )
                uri?.let {
                    contentResolver.openOutputStream(it)?.use { os ->
                        os.write(content.toByteArray())
                    }
                    true
                } ?: false
            } else {
                // Android 9 이하: 직접 파일 저장
                val dir = getLogsDir()
                if (!dir.exists()) dir.mkdirs()
                val file = File(dir, filename)
                file.writeText(content)
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
