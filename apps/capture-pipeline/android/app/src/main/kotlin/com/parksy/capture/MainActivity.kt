package com.parksy.capture

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

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
                    "searchLogs" -> {
                        val query = call.argument<String>("query") ?: ""
                        val results = searchLogs(query)
                        result.success(results)
                    }
                    "updateLogMeta" -> {
                        val filename = call.argument<String>("filename") ?: ""
                        val starred = call.argument<Boolean>("starred")
                        val tags = call.argument<List<String>>("tags")
                        val success = updateLogMeta(filename, starred, tags)
                        result.success(success)
                    }
                    "getLogMeta" -> {
                        val filename = call.argument<String>("filename") ?: ""
                        val meta = getLogMeta(filename)
                        result.success(meta)
                    }
                    "getAllMeta" -> {
                        val meta = getAllMeta()
                        result.success(meta)
                    }
                    "getStats" -> {
                        val stats = getStats()
                        result.success(stats)
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

    private fun getMetaFile(): File {
        return File(getLogsDir(), ".parksy-meta.json")
    }

    private fun getLogFiles(): List<Map<String, Any>> {
        val dir = getLogsDir()
        if (!dir.exists()) return emptyList()
        
        val meta = loadAllMeta()
        
        return dir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".md") && !it.name.startsWith(".") }
            ?.sortedByDescending { it.lastModified() }
            ?.map { file ->
                val fileMeta = meta[file.name] ?: emptyMap()
                val preview = getPreview(file)
                mapOf(
                    "name" to file.name,
                    "size" to file.length(),
                    "modified" to file.lastModified(),
                    "preview" to preview,
                    "starred" to (fileMeta["starred"] as? Boolean ?: false),
                    "tags" to (fileMeta["tags"] as? List<*> ?: emptyList<String>())
                )
            } ?: emptyList()
    }

    private fun getPreview(file: File, maxLines: Int = 3, maxChars: Int = 150): String {
        return try {
            val content = file.readText()
            val body = extractBody(content)
            val lines = body.split("\n")
                .filter { it.isNotBlank() }
                .take(maxLines)
                .joinToString(" ")
            if (lines.length > maxChars) {
                lines.substring(0, maxChars) + "..."
            } else {
                lines
            }
        } catch (e: Exception) {
            ""
        }
    }

    private fun extractBody(content: String): String {
        val lines = content.split("\n")
        var startIndex = 0
        
        if (lines.isNotEmpty() && lines[0].trim() == "---") {
            for (i in 1 until lines.size) {
                if (lines[i].trim() == "---") {
                    startIndex = i + 1
                    break
                }
            }
        }
        
        return lines.drop(startIndex).joinToString("\n").trim()
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
            if (file.exists()) {
                val deleted = file.delete()
                if (deleted) {
                    removeFromMeta(filename)
                }
                deleted
            } else false
        } catch (e: Exception) {
            false
        }
    }

    private fun searchLogs(query: String): List<Map<String, Any>> {
        val dir = getLogsDir()
        if (!dir.exists() || query.isBlank()) return emptyList()
        
        val lowerQuery = query.lowercase()
        val meta = loadAllMeta()
        
        return dir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".md") && !it.name.startsWith(".") }
            ?.filter { file ->
                try {
                    val content = file.readText().lowercase()
                    content.contains(lowerQuery) || file.name.lowercase().contains(lowerQuery)
                } catch (e: Exception) {
                    false
                }
            }
            ?.sortedByDescending { it.lastModified() }
            ?.map { file ->
                val fileMeta = meta[file.name] ?: emptyMap()
                mapOf(
                    "name" to file.name,
                    "size" to file.length(),
                    "modified" to file.lastModified(),
                    "preview" to getPreview(file),
                    "starred" to (fileMeta["starred"] as? Boolean ?: false),
                    "tags" to (fileMeta["tags"] as? List<*> ?: emptyList<String>())
                )
            } ?: emptyList()
    }

    private fun loadAllMeta(): Map<String, Map<String, Any>> {
        return try {
            val metaFile = getMetaFile()
            if (metaFile.exists()) {
                val json = JSONObject(metaFile.readText())
                val result = mutableMapOf<String, Map<String, Any>>()
                json.keys().forEach { key ->
                    val obj = json.getJSONObject(key)
                    val map = mutableMapOf<String, Any>()
                    map["starred"] = obj.optBoolean("starred", false)
                    val tagsArray = obj.optJSONArray("tags")
                    val tags = mutableListOf<String>()
                    if (tagsArray != null) {
                        for (i in 0 until tagsArray.length()) {
                            tags.add(tagsArray.getString(i))
                        }
                    }
                    map["tags"] = tags
                    result[key] = map
                }
                result
            } else {
                emptyMap()
            }
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private fun saveMeta(meta: Map<String, Map<String, Any>>) {
        try {
            val json = JSONObject()
            meta.forEach { (filename, data) ->
                val obj = JSONObject()
                obj.put("starred", data["starred"] ?: false)
                obj.put("tags", data["tags"] ?: emptyList<String>())
                json.put(filename, obj)
            }
            val metaFile = getMetaFile()
            metaFile.writeText(json.toString(2))
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateLogMeta(filename: String, starred: Boolean?, tags: List<String>?): Boolean {
        return try {
            val meta = loadAllMeta().toMutableMap()
            val current = meta[filename]?.toMutableMap() ?: mutableMapOf()
            
            if (starred != null) current["starred"] = starred
            if (tags != null) current["tags"] = tags
            
            meta[filename] = current
            saveMeta(meta)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun removeFromMeta(filename: String) {
        try {
            val meta = loadAllMeta().toMutableMap()
            meta.remove(filename)
            saveMeta(meta)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getLogMeta(filename: String): Map<String, Any> {
        val meta = loadAllMeta()
        return meta[filename] ?: mapOf("starred" to false, "tags" to emptyList<String>())
    }

    private fun getAllMeta(): Map<String, Map<String, Any>> {
        return loadAllMeta()
    }

    private fun getStats(): Map<String, Any> {
        val dir = getLogsDir()
        if (!dir.exists()) return mapOf(
            "totalLogs" to 0,
            "totalSize" to 0L,
            "starredCount" to 0,
            "oldestLog" to 0L,
            "newestLog" to 0L
        )
        
        val files = dir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".md") && !it.name.startsWith(".") }
            ?: emptyList()
        
        val meta = loadAllMeta()
        val starredCount = meta.count { it.value["starred"] == true }
        
        return mapOf(
            "totalLogs" to files.size,
            "totalSize" to files.sumOf { it.length() },
            "starredCount" to starredCount,
            "oldestLog" to (files.minOfOrNull { it.lastModified() } ?: 0L),
            "newestLog" to (files.maxOfOrNull { it.lastModified() } ?: 0L)
        )
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
