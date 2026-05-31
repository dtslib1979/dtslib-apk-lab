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
import org.json.JSONArray
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import android.speech.tts.TextToSpeech
import java.util.Locale

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
                    "onDeviceSearch" -> {
                        val query = call.argument<String>("query") ?: ""
                        val mode = call.argument<String>("mode") ?: "search"
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val searchResult = localTextSearch(query, mode)
                                result.success(searchResult)
                            } catch (e: Exception) {
                                Log.e(TAG, "localTextSearch failed", e)
                                result.error("SEARCH_ERROR", e.message, null)
                            }
                        }
                    }
                    "convertToJsonl" -> {
                        val filename = call.argument<String>("filename") ?: ""
                        val jsonl = convertToJsonl(filename)
                        result.success(jsonl)
                    }
                    "convertAllToJsonl" -> {
                        val results = convertAllToJsonl()
                        result.success(results)
                    }
                    "generateProfile" -> {
                        // CoroutineScope(IO) for AI-powered profiling
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val resultMap = generateProfileWithAI()
                                result.success(resultMap)
                            } catch (e: Exception) {
                                // Fallback to rule-based on failure
                                val fallback = generateProfile()
                                result.success(fallback)
                            }
                        }
                    }
                    "generateMCP" -> {
                        val profileJson = call.argument<String>("profile") ?: ""
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val code = generateMCP(profileJson)
                                result.success(code)
                            } catch (e: Exception) {
                                result.error("MCP_ERROR", e.message, null)
                            }
                        }
                    }
                    "speakText" -> {
                        val text = call.argument<String>("text") ?: ""
                        speakText(text)
                        result.success(true)
                    }
                    "stopSpeaking" -> {
                        stopSpeaking()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ============================================================
    // TTS (Text-to-Speech) — 읽어주기 기능
    // ============================================================

    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private var ttsChunkIndex = 0
    private val ttsChunkSize = 4000

    private fun initTTS() {
        if (tts == null) {
            tts = TextToSpeech(this) { status ->
                isTtsReady = (status == TextToSpeech.SUCCESS)
                if (isTtsReady) {
                    tts?.language = Locale.KOREAN
                    tts?.setSpeechRate(0.85f)
                    tts?.setPitch(1.0f)
                }
            }
        }
    }

    private fun speakText(text: String) {
        if (!isTtsReady) initTTS()
        if (!isTtsReady) {
            Handler(Looper.getMainLooper()).postDelayed({
                if (isTtsReady) {
                    speakTextChunked(text)
                }
            }, 1000)
            return
        }
        speakTextChunked(text)
    }

    private fun speakTextChunked(text: String) {
        ttsChunkIndex = 0
        val chunks = text.chunked(ttsChunkSize)
        if (chunks.isEmpty()) return

        // 첫 청크는 QUEUE_FLUSH (기존 재생 중단), 나머지는 QUEUE_ADD (순차 재생)
        chunks.forEachIndexed { index, chunk ->
            val queueMode = if (index == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD
            tts?.speak(chunk, queueMode, null, "tts_chunk_$index")
        }
    }

    private fun stopSpeaking() {
        tts?.stop()
        ttsChunkIndex = 0
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
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

    // ============================================================
    // 온디바이스 RAG 검색 (v11.0.0)
    // ============================================================

    /**
     * 워딩 프로파일 → MCP 서버 코드 생성 (DeepSeek API 직접 호출)
     */
    private fun generateMCP(profileJson: String): String {
        val prompt = buildString {
            appendLine("다음 워딩 프로파일을 기반으로 박씨 전용 MCP 서버 코드(Node.js)를 생성해줘.")
            appendLine()
            appendLine("### 필수 조건")
            appendLine("1. Node.js Express 서버, port 8015")
            appendLine("2. MCP 도구: respond (박씨 말투로 응답), translate (박씨 스타일 번역)")
            appendLine("3. profile.json을 로드해서 말투/워딩/패턴 재현")
            appendLine("4. SSE 엔드포인트 /mcp/sse 포함 (Claude Code 연동)")
            appendLine("5. 한국어 응답 기본")
            appendLine()
            appendLine("### 화자 구분 로직 (필수 포함)")
            appendLine("MCP 서버가 입력받은 대화 로그에서 **박씨(사용자) 발화**만 골라내는 로직을 포함해:")
            appendLine("- `'**You:**', '**User:**', 'user:', 'Me:', '**나:**'` 프리픽스 → 박씨 발화")
            appendLine("- `'**ChatGPT:**', '**Claude:**', 'assistant:', 'ChatGPT said:', '**AI:**'` → AI 발화")
            appendLine("- 프리픽스가 없으면 `classifySpeaker(text, profile)` 함수로 맥락 판단")
            appendLine("- 박씨 발화만 profile 매칭 대상. AI 발화는 무시.")
            appendLine()
            appendLine("### 프로파일")
            appendLine(profileJson)
            appendLine()
            appendLine("코드만 출력해. 설명 없이. 실행 가능한 완전한 server.js여야 함.")
        }

        return try {
            val apiKey = getDeepSeekKey()
            if (apiKey.isEmpty()) return "API 키가 설정되지 않았습니다. Settings에서 DeepSeek API 키를 입력하세요."

            val url = URL("https://api.deepseek.com/v1/chat/completions")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $apiKey")
            conn.doOutput = true
            conn.connectTimeout = 10000
            conn.readTimeout = 60000

            val payload = JSONObject().apply {
                put("model", "deepseek-chat")
                put("max_tokens", 4096)
                put("messages", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "system")
                        put("content", "당신은 MCP 서버를 생성하는 전문가입니다. 실행 가능한 코드만 출력합니다.")
                    })
                    put(JSONObject().apply {
                        put("role", "user")
                        put("content", prompt)
                    })
                })
            }

            conn.outputStream.write(payload.toString().toByteArray())

            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                json.getJSONArray("choices").getJSONObject(0).getJSONObject("message").optString("content", "생성 실패")
            } else {
                "API 오류: HTTP ${conn.responseCode}"
            }
        } catch (e: Exception) {
            "MCP 생성 오류: ${e.message}"
        }
    }

    /**
     * 로컬 텍스트 기반 검색 (키워드 빈도수 매칭).
     * MCP 서버가 없을 때 fallback. NPU/CPU onnxruntime 있으면 나중에 임베딩 검색으로 교체.
     */
    private fun localTextSearch(query: String, mode: String): Map<String, Any> {
        val files = getLogFiles()
        val matched = mutableListOf<Map<String, Any>>()
        val lowerQuery = query.lowercase()
        val queryTerms = lowerQuery.split("\\s+".toRegex()).filter { it.length > 1 }

        if (queryTerms.isEmpty()) {
            return mapOf("answer" to "검색어가 너무 짧습니다.", "references" to emptyList<Map<String, Any>>())
        }

        for (file in files) {
            val filename = file["name"] as? String ?: continue
            val content = readLogFile(filename) ?: continue
            val lowerContent = content.lowercase()

            // 빈도수 스코어링
            var score = 0
            for (term in queryTerms) {
                var start = 0
                while (true) {
                    val idx = lowerContent.indexOf(term, start)
                    if (idx < 0) break
                    score++
                    start = idx + term.length
                }
            }

            if (score > 0) {
                val snippet = extractRelevantSnippet(content, lowerQuery)
                matched.add(mapOf(
                    "filename" to filename,
                    "content" to snippet,
                    "similarity" to score.toDouble(),
                    "metadata" to mapOf(
                        "date" to extractDate(filename),
                        "speaker" to "unknown"
                    )
                ))
            }
        }

        // 점수 기준 정렬
        matched.sortByDescending { it["similarity"] as Double }
        val topResults = matched.take(10)

        // 답변 생성
        val answer = when {
            topResults.isEmpty() -> "관련 기록을 찾을 수 없습니다. 다른 검색어로 시도해보세요."
            mode == "generate" -> generateSummary(topResults, query)
            else -> {
                val sb = StringBuilder()
                sb.appendLine("🔍 ${topResults.size}개의 관련 기록을 찾았습니다.")
                sb.appendLine()
                topResults.take(3).forEachIndexed { i, r ->
                    val fname = (r["filename"] as? String ?: "").replace("ParksyLog_", "").replace(".md", "")
                    sb.appendLine("${i + 1}. $fname (유사도: ${String.format("%.2f", r["similarity"])})")
                }
                if (topResults.size > 3) {
                    sb.appendLine("\n...외 ${topResults.size - 3}개")
                }
                sb.toString()
            }
        }

        return mapOf("answer" to answer, "references" to topResults)
    }

    /**
     * 검색어 주변 컨텍스트 추출 (최대 300자)
     */
    private fun extractRelevantSnippet(content: String, query: String): String {
        val lowerContent = content.lowercase()
        val idx = lowerContent.indexOf(query)
        if (idx < 0) return content.take(200)

        val start = maxOf(0, idx - 80)
        val end = minOf(content.length, idx + query.length + 160)
        val snippet = content.substring(start, end)

        return if (start > 0) "...$snippet..." else snippet
    }

    /**
     * 파일명에서 날짜 추출 (ParksyLog_20260525_143052 → 2026-05-25)
     */
    private fun extractDate(filename: String): String {
        val match = Regex("""ParksyLog_(\d{4})(\d{2})(\d{2})""").find(filename)
        return if (match != null) {
            val values = match.groupValues
            "${values[1]}-${values[2]}-${values[3]}"
        } else {
            ""
        }
    }

    /**
     * 검색 결과로 간단한 요약 생성 (generate 모드)
     */
    private fun generateSummary(results: List<Map<String, Any>>, query: String): String {
        val sb = StringBuilder()
        sb.appendLine("📝 종합 생성 결과")
        sb.appendLine()
        sb.appendLine("질문: $query")
        sb.appendLine()
        sb.appendLine("참조한 기록 (${results.size}개):")

        results.take(5).forEachIndexed { i, r ->
            val fname = (r["filename"] as? String ?: "").replace("ParksyLog_", "").replace(".md", "")
            val content = (r["content"] as? String ?: "").take(200)
            sb.appendLine()
            sb.appendLine("[$i] $fname")
            sb.appendLine("   $content")
        }

        return sb.toString()
    }

    private fun getDeepSeekKey(): String {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        return prefs.getString("deepseek_api_key", "") ?: ""
    }

    // ============================================================
    // Phase 2: 텍스트 변환기 (JSONL 파인튜닝 포맷)
    // ============================================================

    /**
     * 단일 .md 파일 → JSONL 변환
     * 각 줄 = {"messages": [{"role": "user/assistant", "content": "..."}]}
     */
    private fun convertToJsonl(filename: String): String? {
        val content = readLogFile(filename) ?: return null
        val turns = parseConversationTurns(content)
        if (turns.isEmpty()) return null

        val sb = StringBuilder()
        // 메시지 쌍으로 묶기 (user→assistant)
        var i = 0
        while (i < turns.size) {
            val role = turns[i].first
            val text = turns[i].second
            if (role == "user" && i + 1 < turns.size && turns[i + 1].first == "assistant") {
                // user + assistant 쌍
                val entry = JSONObject()
                val messages = JSONArray()
                messages.put(JSONObject().apply {
                    put("role", "user")
                    put("content", turns[i].second)
                })
                messages.put(JSONObject().apply {
                    put("role", "assistant")
                    put("content", turns[i + 1].second)
                })
                entry.put("messages", messages)
                sb.appendLine(entry.toString())
                i += 2
            } else {
                // 단일 메시지
                val entry = JSONObject()
                val messages = JSONArray()
                messages.put(JSONObject().apply {
                    put("role", role)
                    put("content", text)
                })
                entry.put("messages", messages)
                entry.put("reason", "no_pair")
                sb.appendLine(entry.toString())
                i++
            }
        }
        return sb.toString()
    }

    /**
     * 모든 .md 파일 → JSONL 변환 결과 리스트
     */
    private fun convertAllToJsonl(): List<Map<String, Any>> {
        val files = getLogFiles()
        val results = mutableListOf<Map<String, Any>>()

        for (file in files) {
            val filename = file["name"] as? String ?: continue
            val jsonl = convertToJsonl(filename)
            if (jsonl != null) {
                val lines = jsonl.trim().split("\n")
                results.add(mapOf(
                    "filename" to filename.replace(".md", ".jsonl"),
                    "content" to jsonl,
                    "count" to lines.size
                ))
            }
        }
        return results
    }

    /**
     * 마크다운에서 대화 턴 파싱
     * 지원 포맷:
     *   1. "user:", "assistant:", "human:", "ai:" prefix (기존)
     *   2. "**You:**", "**ChatGPT:**", "**User:**", "**Assistant:**" (bold markdown)
     *   3. "> **You:**", "> **ChatGPT:**" (blockquote bold)
     *   4. "Human:", "AI:" (일반 텍스트)
     *   5. 포맷 미인식 시 전체를 user 메시지 1개로 처리 (fallback)
     */
    private fun parseConversationTurns(content: String): List<Pair<String, String>> {
        val body = extractBody(content)
        val lines = body.split("\n")

        // 1~4: 알려진 role 패턴
        val rolePattern = Regex(
            """^(?:\*\*)?(?:>\s*)?(?:\*\*)?(user|assistant|human|ai|system|you|chatgpt|claude)\s*:*\s*(?:\*\*)?\s*(.*)""",
            RegexOption.IGNORE_CASE
        )
        // 보조 패턴: "Me:", "ChatGPT said:", "Claude responded:" 등
        val altRolePattern = Regex(
            """^(?:>\s*)?(?:\*\*)?(?:me|chatgpt said|claude responded|claude|bot)\s*:*\s*(?:\*\*)?\s*(.*)""",
            RegexOption.IGNORE_CASE
        )

        var currentRole = ""
        var currentText = StringBuilder()
        val turns = mutableListOf<Pair<String, String>>()

        fun saveTurn() {
            if (currentRole.isNotEmpty() && currentText.isNotBlank()) {
                turns.add(normalizeRole(currentRole) to currentText.toString().trim())
            }
        }

        for (line in lines) {
            if (line.isBlank()) continue

            // 패턴 1-4: role prefix 매칭
            val match = rolePattern.find(line)
            if (match != null) {
                val rawRole = match.groupValues[1]
                val rest = match.groupValues[2]
                saveTurn()
                currentRole = mapRole(rawRole)
                currentText = StringBuilder(rest)
                continue
            }

            // 보조 패턴: "Me:", "ChatGPT said:"
            val altMatch = altRolePattern.find(line)
            if (altMatch != null) {
                val rest = altMatch.groupValues[1]
                saveTurn()
                currentRole = "user"  // Me → user, ChatGPT said → assistant
                if (line.lowercase().contains("chatgpt") || line.lowercase().contains("claude responded") || line.lowercase().contains("bot")) {
                    currentRole = "assistant"
                }
                currentText = StringBuilder(rest)
                continue
            }

            // role 없이 줄바꿈 계속
            if (currentRole.isNotEmpty()) {
                if (currentText.isNotEmpty()) currentText.append("\n")
                currentText.append(line)
            }
        }
        saveTurn()

        // Fallback: role 전혀 없으면 전체를 user 메시지로
        if (turns.isEmpty() && body.isNotBlank()) {
            turns.add("user" to body.trim())
        }

        return turns
    }

    /**
     * 다양한 role 표기를 정규화
     */
    private fun mapRole(raw: String): String {
        val lower = raw.lowercase()
        return when (lower) {
            "you" -> "user"
            "chatgpt", "claude" -> "assistant"
            else -> lower
        }
    }

    /**
     * 화자 태그 정규화 (human→user, ai→assistant)
     */
    private fun normalizeRole(role: String): String {
        return when (role.lowercase()) {
            "human" -> "user"
            "ai" -> "assistant"
            else -> role.lowercase()
        }
    }

    // ============================================================
    // Phase 3: 워딩 프로파일러
    // ============================================================

    /**
     * 모든 로그 파일을 분석하여 박씨의 말투/워딩/성향 프로파일 생성.
     * (규칙 기반 — 온디바이스 LLM 없이 동작)
     */
    private fun generateProfileWithAI(): Map<String, Any> {
        val files = getLogFiles()
        if (files.isEmpty()) {
            return mapOf("error" to "로그 파일이 없습니다")
        }
    
        // 전체 텍스트 수집 (토큰 제한 고려: 최근 로그 우선, 최대 15만 자)
        val allContent = StringBuilder()
        val fileDates = mutableListOf<String>()
        var totalLen = 0
        val maxChars = 150000
        for (file in files) {
            val filename = file["name"] as? String ?: continue
            val content = readLogFile(filename) ?: continue
            if (totalLen + content.length > maxChars) {
                val remaining = (maxChars - totalLen) * 80 / 100
                if (remaining > 1000) {
                    allContent.appendLine(content.take(remaining))
                    allContent.appendLine("...(truncated)")
                    totalLen = maxChars
                }
                break
            }
            allContent.appendLine(content)
            fileDates.add(extractDate(filename))
            totalLen += content.length
        }
    
        val fullText = allContent.toString()
    
        val prompt = buildString {
            appendLine("다음은 박씨와 AI 어시스턴트 간의 대화 로그(raw)입니다.")
            appendLine()
            appendLine("### 1단계 — 화자 구분")
            appendLine("로그에서 **박씨(인간) 발화**와 **AI(어시스턴트) 발화**를 먼저 구분하세요.")
            appendLine("규칙:")
            appendLine("- '**You:**', '**User:**', 'user:', 'Me:', '**나:**' 등 프리픽스 → 박씨 발화")
            appendLine("- '**ChatGPT:**', '**Claude:**', 'assistant:', 'ChatGPT said:', '**AI:**' 등 프리픽스 → AI 발화")
            appendLine("- 프리픽스가 없어도 맥락상 명백히 박씨 말투면 박씨로 분류")
            appendLine("- 프리픽스가 없어도 맥락상 명백히 AI 말투면 AI로 분류")
            appendLine("- 구분 불가능한 발화는 'unknown'으로 표시하고 프로파일링에서 제외")
            appendLine()
            appendLine("### 2단계 — 프로파일링")
            appendLine("**박씨 발화만** 대상으로 아래 JSON 형식으로 워딩/액션/딕션 프로파일을 추출하세요.")
            appendLine("AI 발화는 절대 프로파일에 포함하지 말 것.")
            appendLine()
            appendLine("### 추출 항목 (JSON 구조)")
        appendLine("""{
  "profile_name": "parksy-wording-v1",
  "speaker_separation": {
    "total_turns": 0,
    "identified_user": 0,
    "identified_ai": 0,
    "unknown": 0
  },
  "verb_patterns": [
    {"pattern": "\\~해봐", "count": 0, "context": ""},
    {"pattern": "\\~만들어", "count": 0, "context": ""}
  ],
  "judgment_expressions": [
    {"expression": "이거 아니냐", "count": 0, "context": ""},
    {"expression": "\\~된 거냐", "count": 0, "context": ""}
  ],
  "decision_patterns": [],
  "domain_terminology": [],
  "tone_spectrum": {
    "direct_command": 0.0,
    "casual_question": 0.0,
    "formal_statement": 0.0
  },
  "communication_style": {
    "avg_sentence_length": "",
    "emoji_usage": "",
    "typing_style": "",
    "key_phrases": [],
    "formality": ""
  },
  "action_triggers": [],
  "recommended_mcp_tools": []
}""")
            appendLine()
            appendLine("### 분석 규칙")
            appendLine("1. JSON만 출력. 설명/코드 블록 금지.")
            appendLine("2. count는 실제 박씨 발화에서 발견된 빈도수로 정확히 기록")
            appendLine("3. 발견되지 않은 패턴은 null 또는 0 또는 빈 배열로 표시")
            appendLine("4. 한국어 기준으로 분석 (영어 패턴도 별도 추출)")
            appendLine("5. MCP 도구 추천은 실제 대화 패턴 기반으로")
            appendLine()
            appendLine("### 대화 로그 (raw, 전처리하지 않은 원본)")
            appendLine("---")
            appendLine(fullText.take(140000))
            appendLine("---")
        }    
        return try {
            val apiKey = getDeepSeekKey()
            if (apiKey.isEmpty()) return mapOf("error" to "API 키가 설정되지 않았습니다.", "ai_analyzed" to false)

            val url = URL("https://api.deepseek.com/v1/chat/completions")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $apiKey")
            conn.doOutput = true
            conn.connectTimeout = 10000
            conn.readTimeout = 120000

            val payload = JSONObject().apply {
                put("model", "deepseek-chat")
                put("max_tokens", 4096)
                put("messages", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "system")
                        put("content", "당신은 언어학적 프로파일링 전문가입니다. 대화 로그에서 화자의 워딩/액션/딕션 특징을 정확히 추출하여 JSON으로 출력합니다.")
                    })
                    put(JSONObject().apply {
                        put("role", "user")
                        put("content", prompt)
                    })
                })
            }

            conn.outputStream.write(payload.toString().toByteArray())

            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                val answer = json.getJSONArray("choices").getJSONObject(0).getJSONObject("message").optString("content", "")
    
                if (answer.isNotBlank()) {
                    // DeepSeek 응답에서 JSON 블록 추출
                    // JSON 블록 추출 (첫 {부터 마지막 }까지)
                    val firstBrace = answer.indexOf("{")
                    val lastBrace = answer.lastIndexOf("}")
                    if (firstBrace >= 0 && lastBrace > firstBrace) {
                        try {
                            val jsonStr = answer.substring(firstBrace, lastBrace + 1)
                            val profileJson = JSONObject(jsonStr)
                            val result = mutableMapOf<String, Any>()
                            for (key in profileJson.keys()) {
                                result[key] = profileJson.get(key)
                            }
                            result["generated_at"] = System.currentTimeMillis()
                            result["total_logs"] = files.size
                            result["ai_analyzed"] = true
                            result["date_range"] = mapOf(
                                "earliest" to (fileDates.minOrNull() ?: ""),
                                "latest" to (fileDates.maxOrNull() ?: "")
                            )
                            return result
                        } catch (_: Exception) {
                            // JSON 파싱 실패 → 원본 텍스트 반환
                        }
                    }
                    // JSON 못 찾으면 raw 텍스트 반환
                    mapOf(
                        "raw_profile" to answer,
                        "total_logs" to files.size,
                        "ai_analyzed" to true,
                        "date_range" to mapOf(
                            "earliest" to (fileDates.minOrNull() ?: ""),
                            "latest" to (fileDates.maxOrNull() ?: "")
                        )
                    )
                } else {
                    throw Exception("Empty response from DeepSeek")
                }
            } else {
                throw Exception("HTTP ${conn.responseCode}")
            }
        } catch (e: Exception) {
            // DeepSeek 실패 → fallback: 에러 정보 포함
            mapOf(
                "error" to "AI 프로파일 실패: ${e.message}",
                "ai_analyzed" to false
            )
        }
    }

    /**
     * 규칙 기반 프로파일 (fallback)
     */
    private fun generateProfile(): Map<String, Any> {
        val files = getLogFiles()
        if (files.isEmpty()) {
            return mapOf("error" to "로그 파일이 없습니다")
        }

        // 전체 텍스트 수집
        val allContent = StringBuilder()
        val fileDates = mutableListOf<String>()
        for (file in files) {
            val filename = file["name"] as? String ?: continue
            val content = readLogFile(filename) ?: continue
            allContent.appendLine(content)
            fileDates.add(extractDate(filename))
        }

        val fullText = allContent.toString()
        val lowerText = fullText.lowercase()

        // 1. 자주 사용되는 단어 추출 (간단한 빈도수)
        val stopWords = setOf(
            "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "can", "shall", "to", "of", "in", "for",
            "on", "with", "at", "by", "from", "as", "into", "through", "during",
            "before", "after", "above", "below", "between", "out", "off", "over",
            "under", "again", "further", "then", "once", "here", "there", "when",
            "where", "why", "how", "all", "each", "every", "both", "few", "more",
            "most", "other", "some", "such", "no", "nor", "not", "only", "own",
            "same", "so", "than", "too", "very", "just", "because", "but", "and",
            "or", "if", "while", "that", "this", "these", "those", "it", "its",
            "이", "그", "저", "것", "수", "등", "및", "의", "에", "를", "을", "는",
            "은", "가", "이", "들", "은", "는", "하다"
        )

        val wordFreq = mutableMapOf<String, Int>()
        // 한글+영어 단어 추출
        val words = Regex("""[가-힣a-zA-Z]{2,}""").findAll(fullText)
        for (w in words) {
            val word = w.value.lowercase()
            if (word !in stopWords && word.length >= 2) {
                wordFreq[word] = (wordFreq[word] ?: 0) + 1
            }
        }

        val topWords = wordFreq.entries
            .sortedByDescending { it.value }
            .take(50)
            .map { it.key }

        // 2. 문장 패턴 감지
        val sentencePatterns = detectSentencePatterns(fullText)

        // 3. 기술 도메인 추정
        val domainKeywords = mapOf(
            "engineering" to listOf("코드", "api", "server", "db", "database", "배포",
                "deploy", "git", "python", "javascript", "docker", "function",
                "알고리즘", "최적화", "클라우드", "인프라"),
            "philosophy" to listOf("인간", "존재", "의미", "철학", "사상", "논리",
                "가치", "진리", "인식", "본질"),
            "business" to listOf("수익", "비용", "고객", "시장", "전략", "마케팅",
                "매출", "투자", "계약", "협상"),
            "design" to listOf("ui", "ux", "디자인", "레이아웃", "색상", "폰트",
                "typography", "그리드", "와이어프레임", "프로토타입")
        )

        val domainScores = mutableMapOf<String, Double>()
        for ((domain, keywords) in domainKeywords) {
            var score = 0.0
            for (kw in keywords) {
                val count = Regex(kw, RegexOption.IGNORE_CASE).findAll(fullText).count()
                score += count * 1.0
            }
            if (score > 0) domainScores[domain] = score
        }

        // 정규화
        val maxScore = domainScores.values.maxOrNull() ?: 1.0
        val normalizedDomains = domainScores.mapValues { it.value / maxScore }

        // 4. 대화 길이 통계
        val turns = parseConversationTurns(fullText)
        val userTurns = turns.filter { it.first == "user" }
        val assistantTurns = turns.filter { it.first == "assistant" }

        // 5. 프로파일 JSON 생성
        val profile = mapOf(
            "profile_name" to "parksy-v1",
            "generated_at" to System.currentTimeMillis(),
            "total_logs" to files.size,
            "total_turns" to turns.size,
            "vocabulary" to mapOf(
                "frequent_terms" to topWords.take(20),
                "total_unique_words" to wordFreq.size,
                "sentence_patterns" to sentencePatterns
            ),
            "conversation_stats" to mapOf(
                "avg_user_tokens" to if (userTurns.isNotEmpty())
                    userTurns.map { it.second.length }.average() else 0.0,
                "avg_assistant_tokens" to if (assistantTurns.isNotEmpty())
                    assistantTurns.map { it.second.length }.average() else 0.0,
                "user_turns" to userTurns.size,
                "assistant_turns" to assistantTurns.size
            ),
            "domain_weights" to normalizedDomains,
            "date_range" to mapOf(
                "earliest" to (fileDates.minOrNull() ?: ""),
                "latest" to (fileDates.maxOrNull() ?: "")
            )
        )

        return profile
    }

    /**
     * 문장 패턴 감지 (규칙 기반)
     */
    private fun detectSentencePatterns(text: String): List<String> {
        val patterns = mutableListOf<String>()

        // "~해 봐" 패턴
        if (Regex("""[가-힣]+해\s*봐""").containsMatchIn(text)) {
            patterns.add("\"{action} 해 봐\" — 명령형 패턴")
        }
        // "~아니냐" 패턴
        if (Regex("""[가-힣]+아니냐""").containsMatchIn(text)) {
            patterns.add("\"{판단} 아니냐\" — 확인/동의 요청")
        }
        // "~거야" 패턴
        if (Regex("""[가-힣]+거야""").containsMatchIn(text)) {
            patterns.add("\"{설명} 거야\" — 설명형")
        }
        // "~하는 게" 패턴
        if (Regex("""[가-힣]+하는\s*게""").containsMatchIn(text)) {
            patterns.add("\"{행동}하는 게 {조언}\" — 권유형")
        }
        // 코드 관련 패턴
        if (Regex("""`[^`]+`""").containsMatchIn(text)) {
            patterns.add("코드 블록/인라인 코드 자주 사용")
        }

        return patterns.distinct()
    }

    private fun getLegacyLogsDir(): File {
        return File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            ), LOGS_FOLDER
        )
    }
}
