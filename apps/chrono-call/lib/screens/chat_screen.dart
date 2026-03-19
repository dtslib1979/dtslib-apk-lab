import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ── 팔레트 ────────────────────────────────────────────────────
const _kBg      = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kCard    = Color(0xFF1C1C1C);
const _kAccent  = Color(0xFF4FC3F7);   // 차분한 블루
const _kAccentDim = Color(0xFF1A3A4A);
const _kText    = Color(0xFFF5F5F5);
const _kMuted   = Color(0xFF666666);
const _kBorder  = Color(0xFF2A2A2A);
const _kUser    = Color(0xFF2E7D32);   // 내 버블 (초록)
const _kAI      = Color(0xFF1565C0);   // AI 버블 (블루)

const _systemPrompt = '''You are a world-class scholar and expert across all academic disciplines.
The user is a non-specialist curious thinker who tests hypotheses through conversation.
Respond in Korean unless the user switches to another language.
Be precise, cite relevant theories/scholars when applicable, and help the user
develop their thinking step by step. Keep responses conversational — this is a
phone call, not a lecture. Under 150 words per turn.''';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _ch = MethodChannel('com.parksy.chronocall/voice');

  final _scrollCtrl = ScrollController();
  final _messages = <_Msg>[];

  bool _listening = false;
  bool _thinking  = false;
  bool _speaking  = false;
  String _partial = '';
  String? _apiKey;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _setupNativeCallbacks();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.notification.request();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _apiKey = prefs.getString('claude_api_key'));
  }

  void _setupNativeCallbacks() {
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSTTResult':
          final text = call.arguments as String;
          if (mounted) setState(() => _partial = text);
          break;
        case 'onSTTDone':
          final text = call.arguments as String;
          if (text.isNotEmpty && mounted) {
            setState(() => _partial = '');
            _addMessage(text, isUser: true);
            _sendToClaude(text);
          }
          break;
        case 'onSTTError':
          if (mounted) setState(() { _listening = false; _partial = ''; });
          break;
        case 'onTTSDone':
          if (mounted) setState(() => _speaking = false);
          break;
        case 'onMediaButton':
          // 이어버드 버튼 → 토글
          _listening ? _stopListening() : _startListening();
          break;
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── STT 제어 ───────────────────────────────────────────────
  Future<void> _startListening() async {
    if (_thinking || _speaking) return;
    try {
      await _ch.invokeMethod('startSTT');
      if (mounted) setState(() => _listening = true);
    } catch (e) {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _stopListening() async {
    try { await _ch.invokeMethod('stopSTT'); } catch (_) {}
    if (mounted) setState(() => _listening = false);
  }

  // ── Edge TTS (Microsoft 신경망 음성, 무료) ──────────────────
  // Edge 브라우저가 쓰는 동일한 엔드포인트 — API 키 불필요
  static const _edgeVoice = 'ko-KR-SunHiNeural';  // 한국어 여성
  static const _edgeVoiceEn = 'en-US-AriaNeural';  // 영어

  Future<void> _speak(String text) async {
    setState(() => _speaking = true);
    try {
      // Edge TTS REST endpoint
      final voice = RegExp(r'[가-힣]').hasMatch(text) ? _edgeVoice : _edgeVoiceEn;
      final ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ko-KR">'
          '<voice name="$voice">$text</voice></speak>';

      final res = await http.post(
        Uri.parse('https://eastus.tts.speech.microsoft.com/cognitiveservices/v1'),
        headers: {
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-32kbitrate-mono-mp3',
          'User-Agent': 'edge-tts-android',
          'Ocp-Apim-Subscription-Key': 'edge-free', // fallback
        },
        body: ssml,
      );

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        // 오디오 파일 저장 → 네이티브 재생
        final tmp = await getTemporaryDirectory();
        final audioPath = '${tmp.path}/tts_output.mp3';
        await File(audioPath).writeAsBytes(res.bodyBytes);
        await _ch.invokeMethod('playAudio', {'path': audioPath});
      } else {
        // Edge TTS 실패 시 Android TTS fallback
        await _ch.invokeMethod('speak', {'text': text});
      }
    } catch (_) {
      // fallback to native TTS
      try { await _ch.invokeMethod('speak', {'text': text}); } catch (_) {}
    }
  }

  Future<void> _stopSpeaking() async {
    try { await _ch.invokeMethod('stopAudio'); } catch (_) {}
    try { await _ch.invokeMethod('stopTTS'); } catch (_) {}
    if (mounted) setState(() => _speaking = false);
  }

  // ── Google 번역 (무료) ──────────────────────────────────────
  String _targetLang = 'en';
  static const _langOptions = [
    ('en', 'English'), ('ja', '日本語'), ('zh-CN', '中文'),
    ('es', 'Español'), ('fr', 'Français'), ('de', 'Deutsch'),
    ('ko', '한국어'), ('pt', 'Português'), ('ru', 'Русский'),
    ('ar', 'العربية'), ('hi', 'हिन्दी'), ('vi', 'Tiếng Việt'),
  ];

  Future<void> _translateLastMessage() async {
    if (_messages.isEmpty) return;
    final lastAI = _messages.reversed.firstWhere(
      (m) => !m.isUser, orElse: () => _messages.last);
    final text = lastAI.text;

    try {
      final encoded = Uri.encodeComponent(text);
      final url = 'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=auto&tl=$_targetLang&dt=t&q=$encoded';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final translated = (data[0] as List).map((s) => s[0]).join('');
        _addMessage('🌐 [$_targetLang] $translated', isUser: false);
        _speak(translated);
      }
    } catch (e) {
      _addMessage('❌ Translation error: $e', isUser: false);
    }
  }

  void _showLangPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: _langOptions.map((l) => ListTile(
          title: Text(l.$2, style: const TextStyle(color: _kText)),
          trailing: _targetLang == l.$1
              ? const Icon(Icons.check, color: _kAccent, size: 18) : null,
          onTap: () {
            setState(() => _targetLang = l.$1);
            Navigator.pop(context);
            _translateLastMessage();
          },
        )).toList(),
      ),
    );
  }

  // ── 녹음 제어 ──────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_recording) {
      await _ch.invokeMethod('stopRecording');
      setState(() => _recording = false);
    } else {
      await _ch.invokeMethod('startForeground');
      await _ch.invokeMethod('startRecording');
      setState(() => _recording = true);
    }
  }

  // ── Claude API ──────────────────────────────────────────────
  Future<void> _sendToClaude(String userText) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _addMessage('⚠️ API 키를 설정하세요 (우측 상단 ⚙️)', isUser: false);
      return;
    }

    setState(() => _thinking = true);

    // 대화 이력 구성 (최근 20턴)
    final history = _messages.reversed.take(40).toList().reversed.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    try {
      final res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 1024,
          'system': _systemPrompt,
          'messages': history,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['content'][0]['text'] as String;
        _addMessage(reply, isUser: false);
        _speak(reply);
      } else {
        _addMessage('❌ API Error ${res.statusCode}: ${res.body}', isUser: false);
      }
    } catch (e) {
      _addMessage('❌ Network: $e', isUser: false);
    }

    if (mounted) setState(() => _thinking = false);
  }

  void _addMessage(String text, {required bool isUser}) {
    setState(() {
      _messages.add(_Msg(text: text, isUser: isUser, time: DateTime.now()));
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── 대화 저장 ──────────────────────────────────────────────
  Future<void> _saveConversation() async {
    if (_messages.isEmpty) return;
    final dir = Directory('/sdcard/Download/ChronoCall');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/call_$ts.md');
    final buf = StringBuffer('# ChronoCall — $ts\n\n');
    for (final m in _messages) {
      final prefix = m.isUser ? '**나**' : '**Claude**';
      final time = DateFormat('HH:mm:ss').format(m.time);
      buf.writeln('[$time] $prefix: ${m.text}\n');
    }
    await file.writeAsString(buf.toString());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장: ${file.path}')),
      );
    }
  }

  // ── API 키 설정 ─────────────────────────────────────────────
  void _showSettings() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('Claude API Key', style: TextStyle(color: _kText)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: _kText, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'sk-ant-...',
            hintStyle: const TextStyle(color: _kMuted),
            filled: true,
            fillColor: _kBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('claude_api_key', ctrl.text.trim());
              setState(() => _apiKey = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildChatList()),
            if (_partial.isNotEmpty) _buildPartialBar(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _kAccentDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kAccent.withOpacity(0.6), width: 1.5),
            ),
            child: const Center(child: Text('🎙️', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CHRONOCALL',
                    style: TextStyle(color: _kText, fontSize: 16,
                        fontWeight: FontWeight.w900, letterSpacing: 3)),
                Text(
                  _thinking ? 'Thinking...' :
                  _speaking ? 'Speaking...' :
                  _listening ? 'Listening...' :
                  _recording ? '● REC' :
                  'AI Scholar Hotline  v2.0',
                  style: TextStyle(
                    color: _thinking || _speaking ? _kAccent :
                           _listening ? Colors.greenAccent :
                           _recording ? Colors.redAccent : _kMuted,
                    fontSize: 10, letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_recording ? Icons.stop_circle : Icons.fiber_manual_record,
                color: _recording ? Colors.redAccent : _kMuted, size: 20),
            onPressed: _toggleRecording,
            tooltip: _recording ? 'Stop recording' : 'Record',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt, color: _kMuted, size: 20),
            onPressed: _saveConversation,
            tooltip: 'Save conversation',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: _kMuted, size: 20),
            onPressed: _showSettings,
            tooltip: 'API Key',
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎙️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('마이크 버튼을 눌러 대화 시작',
                style: TextStyle(color: _kMuted, fontSize: 14)),
            const SizedBox(height: 8),
            Text('이어버드 버튼으로도 제어 가능',
                style: TextStyle(color: _kMuted.withOpacity(0.5), fontSize: 11)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? _kUser.withOpacity(0.2) : _kAI.withOpacity(0.15),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: Border.all(
            color: isUser ? _kUser.withOpacity(0.3) : _kAI.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text, style: const TextStyle(color: _kText, fontSize: 14, height: 1.4)),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.time),
              style: const TextStyle(color: _kMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _kSurface,
      child: Row(
        children: [
          const SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.greenAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_partial,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12,
                    fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 번역 버튼
          GestureDetector(
            onTap: _messages.isEmpty ? null : _showLangPicker,
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kCard,
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.translate, color: _kMuted, size: 22),
            ),
          ),

          // 스피킹 중이면 정지 버튼
          if (_speaking)
            GestureDetector(
              onTap: _stopSpeaking,
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.2),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: const Icon(Icons.stop, color: Colors.orange, size: 28),
              ),
            ),

          // 메인 마이크 버튼
          GestureDetector(
            onTap: _thinking ? null : (_listening ? _stopListening : _startListening),
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listening ? Colors.greenAccent :
                       _thinking ? _kAccentDim : _kAccent,
                boxShadow: _listening ? [
                  BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 20),
                ] : null,
              ),
              child: Icon(
                _listening ? Icons.mic : _thinking ? Icons.hourglass_top : Icons.mic_none,
                color: _listening ? _kBg : Colors.white,
                size: 32,
              ),
            ),
          ),

          // 빈 공간 (대칭)
          if (!_speaking)
            const SizedBox(width: 50),
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  final DateTime time;
  const _Msg({required this.text, required this.isUser, required this.time});
}
