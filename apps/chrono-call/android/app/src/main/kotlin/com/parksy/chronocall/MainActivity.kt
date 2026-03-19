package com.parksy.chronocall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.parksy.chronocall/voice"
    private var channel: MethodChannel? = null

    private var speechRecognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var recorder: MediaRecorder? = null
    private var recordPath: String? = null
    private var mediaPlayer: MediaPlayer? = null
    private var isListening = false

    // 미디어 버튼 수신
    private val mediaButtonReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val event = intent?.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT) ?: return
            if (event.action != KeyEvent.ACTION_DOWN) return
            when (event.keyCode) {
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                KeyEvent.KEYCODE_HEADSETHOOK -> {
                    // Buds Pro 1탭 → 말하기 토글
                    runOnUiThread { channel?.invokeMethod("onMediaButton", null) }
                }
                KeyEvent.KEYCODE_MEDIA_NEXT -> {
                    // Buds Pro 2탭 → TTS 정지
                    tts?.stop()
                    runOnUiThread { channel?.invokeMethod("onTTSDone", null) }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tts = TextToSpeech(this, this)

        // 블루투스 오디오 라우팅
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        am.mode = AudioManager.MODE_IN_COMMUNICATION
        am.isBluetoothScoOn = true
        am.startBluetoothSco()

        // 미디어 버튼 등록
        val filter = IntentFilter(Intent.ACTION_MEDIA_BUTTON)
        filter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        registerReceiver(mediaButtonReceiver, filter)
    }

    override fun onDestroy() {
        try { unregisterReceiver(mediaButtonReceiver) } catch (_: Exception) {}
        speechRecognizer?.destroy()
        tts?.shutdown()
        recorder?.release()
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        am.stopBluetoothSco()
        am.isBluetoothScoOn = false
        super.onDestroy()
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.KOREAN
            tts?.setSpeechRate(1.1f)
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {
                    runOnUiThread { channel?.invokeMethod("onTTSDone", null) }
                }
                @Deprecated("Deprecated") override fun onError(utteranceId: String?) {
                    runOnUiThread { channel?.invokeMethod("onTTSDone", null) }
                }
            })
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startSTT" -> { startSTT(); result.success(true) }
                "stopSTT"  -> { stopSTT(); result.success(true) }
                "speak"    -> {
                    val text = call.argument<String>("text") ?: ""
                    speak(text)
                    result.success(true)
                }
                "stopTTS"  -> { tts?.stop(); result.success(true) }
                "playAudio" -> {
                    val path = call.argument<String>("path") ?: ""
                    playAudio(path)
                    result.success(true)
                }
                "stopAudio" -> {
                    mediaPlayer?.stop()
                    mediaPlayer?.release()
                    mediaPlayer = null
                    runOnUiThread { channel?.invokeMethod("onTTSDone", null) }
                    result.success(true)
                }
                "startRecording" -> { startRecording(); result.success(true) }
                "stopRecording"  -> { stopRecording(); result.success(recordPath) }
                "startForeground" -> {
                    val svc = Intent(this, VoiceService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(svc)
                    } else { startService(svc) }
                    result.success(true)
                }
                "stopForeground" -> {
                    stopService(Intent(this, VoiceService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── STT ───────────────────────────────────────────────
    private fun startSTT() {
        if (isListening) return
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() { isListening = false }
            override fun onError(error: Int) {
                isListening = false
                runOnUiThread { channel?.invokeMethod("onSTTError", error) }
            }
            override fun onResults(results: Bundle?) {
                isListening = false
                val texts = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = texts?.firstOrNull() ?: ""
                runOnUiThread { channel?.invokeMethod("onSTTDone", text) }
            }
            override fun onPartialResults(partial: Bundle?) {
                val texts = partial?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = texts?.firstOrNull() ?: ""
                if (text.isNotEmpty()) {
                    runOnUiThread { channel?.invokeMethod("onSTTResult", text) }
                }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ko-KR")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        speechRecognizer?.startListening(intent)
        isListening = true
    }

    private fun stopSTT() {
        speechRecognizer?.stopListening()
        isListening = false
    }

    // ── TTS ───────────────────────────────────────────────
    private fun speak(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "chronocall_utterance")
    }

    // ── Audio Playback (Edge TTS MP3) ──────────────────────
    private fun playAudio(path: String) {
        mediaPlayer?.release()
        mediaPlayer = MediaPlayer().apply {
            setDataSource(path)
            setAudioStreamType(AudioManager.STREAM_VOICE_CALL)
            setOnCompletionListener {
                release()
                mediaPlayer = null
                runOnUiThread { channel?.invokeMethod("onTTSDone", null) }
            }
            prepare()
            start()
        }
    }

    // ── Recording ─────────────────────────────────────────
    private fun startRecording() {
        try {
            val dir = File(cacheDir, "recordings")
            if (!dir.exists()) dir.mkdirs()
            recordPath = "${dir.absolutePath}/call_${System.currentTimeMillis()}.m4a"

            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION") MediaRecorder()
            }
            recorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(recordPath)
                prepare()
                start()
            }
        } catch (e: Exception) {
            recorder?.release()
            recorder = null
        }
    }

    private fun stopRecording() {
        try {
            recorder?.stop()
            recorder?.release()
        } catch (_: Exception) {}
        recorder = null
    }
}
