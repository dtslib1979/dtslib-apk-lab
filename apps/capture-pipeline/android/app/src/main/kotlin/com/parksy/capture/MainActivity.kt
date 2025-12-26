package com.parksy.capture

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val TAG = "ParksyCapture"
    private val CHANNEL = "com.parksy.capture/share"
    private var sharedText: String? = null
    private var isShareIntent: Boolean = false
    private val LOGS_FOLDER = "parksy-logs"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        requestStoragePermissions()
    }

    private fun requestStoragePermissions() {
        // Android 11+ (API 30+): Use MANAGE_EXTERNAL_STORAGE for full access
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                Log.d(TAG, "Requesting MANAGE_EXTERNAL_STORAGE permission")
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                }
            }
        } else {
            // Android 10 and below: Use traditional permissions
            val permissions = arrayOf(
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            )
            val notGranted = permissions.filter {
                ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
            }
            if (notGranted.isNotEmpty()) {
                ActivityCompat.requestPermissions(this, notGranted.toTypedArray(), 1001)
            }
        }
    }

    private fun hasFullStorageAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }
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
                    "hasStoragePermission" -> {
                        result.success(hasFullStorageAccess())
                    }
                    "requestStoragePermission" -> {
                        requestStoragePermissions()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ============================================================
    // MediaStore-based file operations (Android 10+ Scoped Storage)
    // ============================================================

    private fun getLogFiles(): List<Map<String, Any>> {
        val files = mutableListOf<Map<String, Any>>()
        val meta = loadAllMeta()

        Log.d(TAG, "getLogFiles() called, SDK: ${Build.VERSION.SDK_INT}, hasFullAccess: ${hasFullStorageAccess()}")

        // With MANAGE_EXTERNAL_STORAGE permission, always use direct file access
        // This is the most reliable method
        if (hasFullStorageAccess()) {
            Log.d(TAG, "Using direct file access (MANAGE_EXTERNAL_STORAGE granted)")
            tryDirectFileAccess(files, meta)
            Log.d(TAG, "Direct access found ${files.size} files")
            return files
        }

        // Fallback to MediaStore if permission not granted
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Log.d(TAG, "Permission not granted, trying MediaStore fallback")
            val projection = arrayOf(
                MediaStore.Downloads._ID,
                MediaStore.Downloads.DISPLAY_NAME,
                MediaStore.Downloads.SIZE,
                MediaStore.Downloads.DATE_MODIFIED,
                MediaStore.Downloads.RELATIVE_PATH
            )

            val selection = "${MediaStore.Downloads.DISPLAY_NAME} LIKE ?"
            val selectionArgs = arrayOf("ParksyLog_%.md")
            val sortOrder = "${MediaStore.Downloads.DATE_MODIFIED} DESC"

            try {
                contentResolver.query(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder
                )?.use { cursor ->
                    val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID)
                    val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Downloads.DISPLAY_NAME)
                    val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Downloads.SIZE)
                    val modifiedColumn = cursor.getColumnIndexOrThrow(MediaStore.Downloads.DATE_MODIFIED)

                    Log.d(TAG, "MediaStore found ${cursor.count} files")

                    while (cursor.moveToNext()) {
                        val id = cursor.getLong(idColumn)
                        val name = cursor.getString(nameColumn)
                        val size = cursor.getLong(sizeColumn)
                        val modified = cursor.getLong(modifiedColumn) * 1000

                        val uri = Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toString())
                        val preview = getPreviewFromUri(uri)
                        val fileMeta = meta[name] ?: emptyMap()

                        files.add(mapOf(
                            "name" to name,
                            "size" to size,
                            "modified" to modified,
                            "preview" to preview,
                            "starred" to (fileMeta["starred"] as? Boolean ?: false),
                            "tags" to (fileMeta["tags"] as? List<*> ?: emptyList<String>())
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "MediaStore query failed: ${e.message}", e)
            }
        } else {
            tryDirectFileAccess(files, meta)
        }

        Log.d(TAG, "Returning ${files.size} log files")
        return files
    }

    private fun tryDirectFileAccess(files: MutableList<Map<String, Any>>, meta: Map<String, Map<String, Any>>) {
        val dir = getLegacyLogsDir()
        Log.d(TAG, "Direct file access: ${dir.absolutePath}, exists: ${dir.exists()}")

        if (dir.exists()) {
            val fileList = dir.listFiles()
            Log.d(TAG, "Files in dir: ${fileList?.size ?: 0}")

            fileList?.filter { it.isFile && it.name.endsWith(".md") && it.name.startsWith("ParksyLog_") }
                ?.sortedByDescending { it.lastModified() }
                ?.forEach { file ->
                    Log.d(TAG, "Found file: ${file.name}")
                    val fileMeta = meta[file.name] ?: emptyMap()
                    files.add(mapOf(
                        "name" to file.name,
                        "size" to file.length(),
                        "modified" to file.lastModified(),
                        "preview" to getPreviewFromFile(file),
                        "starred" to (fileMeta["starred"] as? Boolean ?: false),
                        "tags" to (fileMeta["tags"] as? List<*> ?: emptyList<String>())
                    ))
                }
        }
    }

    private fun getPreviewFromUri(uri: Uri, maxLines: Int = 3, maxChars: Int = 150): String {
        return try {
            contentResolver.openInputStream(uri)?.use { stream ->
                val content = stream.bufferedReader().readText()
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
            } ?: ""
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get preview from URI: ${e.message}")
            ""
        }
    }

    private fun getPreviewFromFile(file: File, maxLines: Int = 3, maxChars: Int = 150): String {
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
        Log.d(TAG, "readLogFile: $filename, hasFullAccess: ${hasFullStorageAccess()}")

        // With MANAGE_EXTERNAL_STORAGE, use direct file access
        if (hasFullStorageAccess()) {
            return try {
                val file = File(getLegacyLogsDir(), filename)
                if (file.exists()) {
                    Log.d(TAG, "Reading file directly: ${file.absolutePath}")
                    file.readText()
                } else {
                    Log.e(TAG, "File not found: ${file.absolutePath}")
                    null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Direct read failed: ${e.message}")
                null
            }
        }

        // Fallback to MediaStore
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val uri = findFileUri(filename)
            if (uri == null) {
                Log.e(TAG, "Could not find URI for: $filename")
                return null
            }
            return try {
                contentResolver.openInputStream(uri)?.use { stream ->
                    stream.bufferedReader().readText()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read file: ${e.message}")
                null
            }
        } else {
            return try {
                val file = File(getLegacyLogsDir(), filename)
                if (file.exists()) file.readText() else null
            } catch (e: Exception) {
                null
            }
        }
    }

    private fun deleteLogFile(filename: String): Boolean {
        Log.d(TAG, "deleteLogFile: $filename, hasFullAccess: ${hasFullStorageAccess()}")

        return try {
            // With MANAGE_EXTERNAL_STORAGE, use direct file delete
            if (hasFullStorageAccess()) {
                val file = File(getLegacyLogsDir(), filename)
                if (file.exists()) {
                    val deleted = file.delete()
                    if (deleted) removeFromMeta(filename)
                    Log.d(TAG, "Direct delete: $deleted")
                    deleted
                } else false
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val uri = findFileUri(filename)
                if (uri != null) {
                    val deleted = contentResolver.delete(uri, null, null) > 0
                    if (deleted) removeFromMeta(filename)
                    deleted
                } else false
            } else {
                val file = File(getLegacyLogsDir(), filename)
                if (file.exists()) {
                    val deleted = file.delete()
                    if (deleted) removeFromMeta(filename)
                    deleted
                } else false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete file: ${e.message}")
            false
        }
    }

    private fun findFileUri(filename: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        
        val projection = arrayOf(
            MediaStore.Downloads._ID,
            MediaStore.Downloads.RELATIVE_PATH
        )
        val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
        val selectionArgs = arrayOf(filename)
        
        try {
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID))
                    val path = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Downloads.RELATIVE_PATH)) ?: ""
                    
                    // Prefer file from parksy-logs folder
                    if (path.contains(LOGS_FOLDER)) {
                        return Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toString())
                    }
                }
                
                // Fallback: return first match
                cursor.moveToFirst()
                if (cursor.count > 0) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID))
                    return Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toString())
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "findFileUri failed: ${e.message}")
        }
        return null
    }

    private fun searchLogs(query: String): List<Map<String, Any>> {
        if (query.isBlank()) return emptyList()
        
        val allFiles = getLogFiles()
        val lowerQuery = query.lowercase()
        
        return allFiles.filter { file ->
            val name = (file["name"] as? String)?.lowercase() ?: ""
            val preview = (file["preview"] as? String)?.lowercase() ?: ""
            
            if (name.contains(lowerQuery) || preview.contains(lowerQuery)) {
                true
            } else {
                // Deep search in content
                val filename = file["name"] as? String ?: ""
                val content = readLogFile(filename)?.lowercase() ?: ""
                content.contains(lowerQuery)
            }
        }
    }

    // ============================================================
    // Metadata management (stored in app-private directory)
    // ============================================================

    private fun getMetaFile(): File {
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
            ?: filesDir
        return File(dir, ".parksy-meta.json")
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
            metaFile.parentFile?.mkdirs()
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
        val files = getLogFiles()
        val meta = loadAllMeta()
        val starredCount = meta.count { it.value["starred"] == true }
        
        val totalSize = files.sumOf { (it["size"] as? Long) ?: 0L }
        val oldest = files.minOfOrNull { (it["modified"] as? Long) ?: Long.MAX_VALUE } ?: 0L
        val newest = files.maxOfOrNull { (it["modified"] as? Long) ?: 0L } ?: 0L
        
        return mapOf(
            "totalLogs" to files.size,
            "totalSize" to totalSize,
            "starredCount" to starredCount,
            "oldestLog" to oldest,
            "newestLog" to newest
        )
    }

    // ============================================================
    // File save and share
    // ============================================================

    private fun shareText(text: String, title: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(intent, title))
    }

    private fun saveFile(filename: String, content: String): Boolean {
        Log.d(TAG, "saveFile: $filename, content length: ${content.length}")

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, filename)
                    put(MediaStore.Downloads.MIME_TYPE, "text/markdown")
                    put(MediaStore.Downloads.RELATIVE_PATH,
                        Environment.DIRECTORY_DOWNLOADS + "/$LOGS_FOLDER")
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                )
                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { os ->
                        os.write(content.toByteArray())
                    }
                    // Force MediaStore to update immediately
                    contentResolver.notifyChange(uri, null)
                    contentResolver.notifyChange(MediaStore.Downloads.EXTERNAL_CONTENT_URI, null)
                    Log.d(TAG, "File saved successfully via MediaStore: $uri")
                    true
                } else {
                    Log.e(TAG, "Failed to insert file into MediaStore")
                    false
                }
            } else {
                val dir = getLegacyLogsDir()
                if (!dir.exists()) dir.mkdirs()
                val file = File(dir, filename)
                file.writeText(content)
                // Trigger media scan for legacy storage
                MediaScannerConnection.scanFile(
                    this,
                    arrayOf(file.absolutePath),
                    arrayOf("text/markdown"),
                    null
                )
                Log.d(TAG, "File saved successfully via File API")
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save file: ${e.message}", e)
            false
        }
    }

    private fun getLegacyLogsDir(): File {
        return File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            ), LOGS_FOLDER
        )
    }
}
