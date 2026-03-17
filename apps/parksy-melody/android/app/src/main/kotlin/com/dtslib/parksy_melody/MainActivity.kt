package com.dtslib.parksy_melody

import android.content.Intent
import android.os.Bundle
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.parksy.melody/intent"
    private var sharedUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            YoutubeDL.getInstance().init(application)
        } catch (e: Exception) {
            // 초기화 실패 시 runYtDlp 호출 때 에러 처리
        }
        extractSharedUrl(intent)
    }

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
                        Thread {
                            try {
                                val request = YoutubeDLRequest(url)
                                request.addOption("-x")
                                request.addOption("--audio-format", "mp3")
                                request.addOption("--audio-quality", "5")
                                request.addOption("--no-playlist")
                                request.addOption("--force-overwrites")
                                request.addOption("-o", output)
                                YoutubeDL.getInstance().execute(request, null, null)
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("YTDLP", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
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
