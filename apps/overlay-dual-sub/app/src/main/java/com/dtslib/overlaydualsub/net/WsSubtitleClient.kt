package com.dtslib.overlaydualsub.net

import com.dtslib.overlaydualsub.model.SubtitleEvent
import okhttp3.*
import org.json.JSONObject

/**
 * WebSocket 자막 클라이언트 (v1 껍데기)
 * 
 * 서버 JSON 형식:
 * {
 *   "segId": 123,
 *   "dictation": "...",
 *   "ko": "...",
 *   "en": "..."
 * }
 */
class WsSubtitleClient(
    private val serverUrl: String = "ws://localhost:8080/subtitle"
) : SubtitleStreamClient {

    private val client = OkHttpClient()
    private var webSocket: WebSocket? = null
    private var onEvent: ((SubtitleEvent) -> Unit)? = null
    private var delayMs = 500L

    override fun start(onEvent: (SubtitleEvent) -> Unit) {
        this.onEvent = onEvent
        val request = Request.Builder().url(serverUrl).build()
        webSocket = client.newWebSocket(request, createListener())
    }

    override fun stop() {
        webSocket?.close(1000, "Client closed")
        webSocket = null
    }

    override fun setDelay(ms: Long) {
        delayMs = ms
        // TODO: 서버에 딜레이 설정 전송 (v2)
    }

    fun sendAudio(data: ByteArray) {
        webSocket?.send(okio.ByteString.of(*data))
    }

    private fun createListener() = object : WebSocketListener() {
        override fun onMessage(webSocket: WebSocket, text: String) {
            try {
                val json = JSONObject(text)
                val event = SubtitleEvent(
                    segId = json.optInt("segId", 0),
                    dictation = json.optString("dictation", ""),
                    ko = json.optString("ko", ""),
                    en = json.optString("en", "")
                )
                onEvent?.invoke(event)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            t.printStackTrace()
        }
    }
}
