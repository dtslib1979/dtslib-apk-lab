package com.parksy.capture

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.widget.Toast
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread

class ShareReceiverActivity : Activity() {

    companion object {
        private const val TAG = "ParksyCapture"

        // TODO: Worker 배포 후 URL 설정
        private const val WORKER_URL = "https://parksy-capture-worker.workers.dev"
        private const val API_KEY = "CHANGE_ME"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 디버깅용 로그 출력
        logIntentDetails(intent)

        // 텍스트 추출 (우선순위대로)
        val text = extractText(intent)

        if (text.isNullOrBlank()) {
            Log.w(TAG, "No text received from intent")
            showToast("No text received. Select text → Share (not page link share).")
            finish()
            return
        }

        Log.i(TAG, "Text received: ${text.length} chars")

        // 파이프라인 실행
        processPipeline(text)
    }

    private fun logIntentDetails(intent: Intent?) {
        Log.d(TAG, "=== Intent Debug Info ===")
        Log.d(TAG, "action: ${intent?.action}")
        Log.d(TAG, "type: ${intent?.type}")
        Log.d(TAG, "extras keys: ${intent?.extras?.keySet()?.toList()}")
        Log.d(TAG, "EXTRA_TEXT: ${intent?.getStringExtra(Intent.EXTRA_TEXT)?.take(100)}...")
        Log.d(TAG, "EXTRA_PROCESS_TEXT: ${intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.take(100)}...")
        Log.d(TAG, "clipData: ${intent?.clipData}")
        Log.d(TAG, "dataString: ${intent?.dataString}")
        Log.d(TAG, "=========================")
    }

    private fun extractText(intent: Intent?): String? {
        if (intent == null) return null

        // 우선순위 1: EXTRA_TEXT (가장 일반적인 Share)
        intent.getStringExtra(Intent.EXTRA_TEXT)?.let {
            if (it.isNotBlank()) {
                Log.d(TAG, "Text from EXTRA_TEXT")
                return it
            }
        }

        // 우선순위 2: EXTRA_PROCESS_TEXT (텍스트 선택 후 처리)
        intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()?.let {
            if (it.isNotBlank()) {
                Log.d(TAG, "Text from EXTRA_PROCESS_TEXT")
                return it
            }
        }

        // 우선순위 3: ClipData (일부 앱에서 사용)
        intent.clipData?.getItemAt(0)?.coerceToText(this)?.toString()?.let {
            if (it.isNotBlank()) {
                Log.d(TAG, "Text from ClipData")
                return it
            }
        }

        return null
    }

    private fun processPipeline(text: String) {
        thread {
            // Step 1: Local save (MUST succeed)
            val localOk = saveLocal(text)

            if (!localOk) {
                runOnUiThread {
                    showToast("Error! Save Failed ❌")
                    finish()
                }
                return@thread
            }

            // Step 2: Cloud save (MAY fail)
            val cloudOk = saveCloud(text)

            runOnUiThread {
                if (cloudOk) {
                    showToast("Saved Local & Cloud 🚀")
                } else {
                    showToast("Saved Local Only ✅")
                }
                finish()
            }
        }
    }

    private fun saveLocal(text: String): Boolean {
        return try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val filename = "ParksyLog_$timestamp.md"
            val content = toMarkdown(text)

            val success = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveWithMediaStore(filename, content)
            } else {
                saveWithDirectFile(filename, content)
            }

            if (success) {
                Log.i(TAG, "Local save success: $filename")
            } else {
                Log.e(TAG, "Local save failed: $filename")
            }

            success
        } catch (e: Exception) {
            Log.e(TAG, "Local save exception", e)
            false
        }
    }

    private fun saveWithMediaStore(filename: String, content: String): Boolean {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, filename)
            put(MediaStore.Downloads.MIME_TYPE, "text/markdown")
            put(MediaStore.Downloads.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS + "/parksy-logs")
        }

        val uri = contentResolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
        )

        return uri?.let {
            contentResolver.openOutputStream(it)?.use { os ->
                os.write(content.toByteArray())
            }
            true
        } ?: false
    }

    private fun saveWithDirectFile(filename: String, content: String): Boolean {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            ), "parksy-logs"
        )
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, filename)
        file.writeText(content)
        return true
    }

    private fun toMarkdown(text: String): String {
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        return """---
date: $timestamp
source: android-share
chars: ${text.length}
---

$text
"""
    }

    private fun saveCloud(text: String): Boolean {
        return try {
            val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())
            val json = """{"text":"${escapeJson(text)}","source":"android","ts":"$timestamp"}"""

            val url = URL(WORKER_URL)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 5000
            conn.readTimeout = 5000
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("X-API-Key", API_KEY)
            conn.doOutput = true

            conn.outputStream.use { os ->
                os.write(json.toByteArray())
            }

            val responseCode = conn.responseCode
            Log.d(TAG, "Cloud save response: $responseCode")

            responseCode == 200 || responseCode == 201
        } catch (e: Exception) {
            Log.w(TAG, "Cloud save failed (expected if not configured)", e)
            false
        }
    }

    private fun escapeJson(text: String): String {
        return text
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}
