package com.dtslib.parksy_melody

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.parksy.melody/intent"
    private var sharedUrl: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedUrl" -> {
                        result.success(sharedUrl)
                        sharedUrl = null
                    }
                    "runYtDlp" -> {
                        val url = call.argument<String>("url")
                        val output = call.argument<String>("output")
                        if (url == null || output == null) {
                            result.error("ARGS", "url/output required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val logPath = "/sdcard/Music/melody_debug.log"
                            // bash -c "cmd" _ $1=output $2=url
                            // $1/$2/$? are literal in Kotlin (not valid identifiers)
                            val cmd = "echo 'RUN_COMMAND fired' > \"$logPath\" 2>&1; " +
                                "/data/data/com.termux/files/usr/bin/python3.12 " +
                                "/data/data/com.termux/files/usr/bin/yt-dlp " +
                                "-x --audio-format mp3 --audio-quality 5 " +
                                "--no-playlist --force-overwrites " +
                                "-o \"$1\" \"$2\" >> \"$logPath\" 2>&1; " +
                                "echo \"EXIT=$?\" >> \"$logPath\""
                            val i = Intent()
                            i.setClassName("com.termux", "com.termux.app.RunCommandService")
                            i.action = "com.termux.RUN_COMMAND"
                            i.putExtra("com.termux.RUN_COMMAND_PATH",
                                "/data/data/com.termux/files/usr/bin/bash")
                            i.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf(
                                "-c", cmd, "_", output, url
                            ))
                            i.putExtra("com.termux.RUN_COMMAND_WORKDIR", "/sdcard/Music")
                            i.putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                            startService(i)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("TERMUX", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractSharedUrl(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        extractSharedUrl(intent)
    }

    private fun extractSharedUrl(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
            val urlRegex = Regex("https?://(www\\.)?(youtube\\.com|youtu\\.be)\\S+")
            sharedUrl = urlRegex.find(text)?.value ?: text.trim()
        }
    }
}
