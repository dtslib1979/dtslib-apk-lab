package com.dtslib.parksy_melody

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.OkHttpClient
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.parksy.melody/intent"
    private var sharedUrl: String? = null

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val npeDownloader = object : Downloader() {
        override fun execute(request: Request): Response {
            val reqBuilder = okhttp3.Request.Builder().url(request.url())
            request.headers().forEach { (key, values) ->
                values.forEach { reqBuilder.addHeader(key, it) }
            }
            // POST body 처리 (visitor_id 등 YouTube API는 POST + JSON body 필수)
            val body = request.dataToSend()
            val method = request.httpMethod()
            when {
                method.equals("POST", ignoreCase = true) ->
                    reqBuilder.post(
                        (body ?: ByteArray(0)).toRequestBody(
                            "application/json; charset=utf-8".toMediaType()
                        )
                    )
                method.equals("HEAD", ignoreCase = true) ->
                    reqBuilder.head()
                // GET은 기본값
            }
            val response = okHttpClient.newCall(reqBuilder.build()).execute()
            return Response(
                response.code,
                response.message,
                response.headers.toMultimap(),
                response.body?.string(),
                response.request.url.toString()
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try { NewPipe.init(npeDownloader) } catch (e: Exception) {}
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
                    "getAudioUrl" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            result.error("ARGS", "url required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                NewPipe.init(npeDownloader)
                                val extractor = ServiceList.YouTube.getStreamExtractor(url)
                                extractor.fetchPage()
                                val audioStream = extractor.audioStreams
                                    .maxByOrNull { it.bitrate }
                                    ?: throw Exception("No audio stream found")
                                runOnUiThread { result.success(audioStream.content) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("NPE", e.message, null) }
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
