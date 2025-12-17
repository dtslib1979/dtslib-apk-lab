package com.parksy.capture

import android.content.Intent
import android.os.Bundle
import android.os.Environment
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.parksy.capture/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDownloads" -> {
                        openDownloadsFolder()
                        result.success(true)
                    }
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        shareText(text)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openDownloadsFolder() {
        try {
            // Try to open file manager to Downloads/parksy-logs
            val intent = Intent(Intent.ACTION_VIEW).apply {
                val path = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                ).path + "/parksy-logs"
                setDataAndType(android.net.Uri.parse("content://com.android.externalstorage.documents/document/primary:Download%2Fparksy-logs"), "vnd.android.document/directory")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback: open Downloads folder
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(android.net.Uri.parse("content://com.android.externalstorage.documents/document/primary:Download"), "vnd.android.document/directory")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            } catch (e2: Exception) {
                // Last fallback: open any file manager
                val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "*/*"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(Intent.createChooser(intent, "Open Downloads"))
            }
        }
    }

    private fun shareText(text: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(intent, "Share via"))
    }
}
