import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ── 카톡 스타일 팔레트 ─────────────────────────────────────────
const _kBg      = Color(0xFF9BBBD4);   // 카톡 채팅방 배경 (블루그레이)
const _kHeader  = Color(0xFF3B4890);   // 상단 바 (진한 네이비)
const _kMyBubble   = Color(0xFFFFEB33); // 내 버블 (카톡 노랑)
const _kAIBubble   = Color(0xFFFFFFFF); // AI 버블 (흰색)
const _kMyText     = Color(0xFF1A1A1A); // 내 텍스트 (검정)
const _kAIText     = Color(0xFF1A1A1A); // AI 텍스트 (검정)
const _kTimeText   = Color(0xFF6B7B8D); // 시간 텍스트
const _kInputBg    = Color(0xFFFFFFFF); // 입력 영역 배경
const _kBottomBar  = Color(0xFFEFEFEF); // 하단 바
const _kAccent     = Color(0xFF4FC3F7);

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
          if (mounted) setState(() => _partial = call.arguments as String);
        case 'onSTTDone':
          final text = call.arguments as String;
          if (text.isNotEmpty && mounted) {
            setState(() => _partial = '');
            _addMessage(text, isUser: true);
            _sendToClaude(text);
          }
        case 'onSTTError':
          if (mounted) setState(() { _listening = false; _partial = ''; });
        case 'onTTSDone':
          if (mounted) setState(() => _speaking = false);
        case 'onMediaButton':
          _listening ? _stopListening() : _startListening();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── STT ──────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (_thinking || _speaking) return;
    try {
      await _ch.invokeMethod('startSTT');
      if (mounted) setState(() => _listening = true);
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _stopListening() async {
    try { await _ch.invokeMethod('stopSTT'); } catch (_) {}
    if (mounted) setState(() => _listening = false);
  }

  // ── Edge TTS (Microsoft 신경망 음성) ────────────────────────
  static const _edgeVoiceKo = 'ko-KR-SunHiNeural';
  static const _edgeVoiceEn = 'en-US-AriaNeural';

  Future<void> _speak(String text) async {
    setState(() => _speaking = true);
    try {
      final voice = RegExp(r'[가-힣]').hasMatch(text) ? _edgeVoiceKo : _edgeVoiceEn;
      final escapedText = text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
      final ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ko-KR">'
          '<voice name="$voice">$escapedText</voice></speak>';

      final res = await http.post(
        Uri.parse('https://eastus.tts.speech.microsoft.com/cognitiveservices/v1'),
        headers: {
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-32kbitrate-mono-mp3',
          'User-Agent': 'edge-tts-android',
        },
        body: ssml,
      );

      if (res.statusCode == 200 && res.bodyBytes.length > 1000) {
        final tmp = await getTemporaryDirectory();
        final path = '${tmp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        await File(path).writeAsBytes(res.bodyBytes);
        await _ch.invokeMethod('playAudio', {'path': path});
      } else {
        await _ch.invokeMethod('speak', {'text': text});
      }
    } catch (_) {
      try { await _ch.invokeMethod('speak', {'text': text}); } catch (_) {}
    }
  }

  Future<void> _stopSpeaking() async {
    try { await _ch.invokeMethod('stopAudio'); } catch (_) {}
    try { await _ch.invokeMethod('stopTTS'); } catch (_) {}
    if (mounted) setState(() => _speaking = false);
  }

  // ── Google 번역 ─────────────────────────────────────────────
  String _targetLang = 'en';
  static const _langOptions = [
    ('en', '🇺🇸 English'), ('ja', '🇯🇵 日本語'), ('zh-CN', '🇨🇳 中文'),
    ('es', '🇪🇸 Español'), ('fr', '🇫🇷 Français'), ('de', '🇩🇪 Deutsch'),
    ('ko', '🇰🇷 한국어'), ('pt', '🇧🇷 Português'), ('ru', '🇷🇺 Русский'),
    ('ar', '🇸🇦 العربية'), ('hi', '🇮🇳 हिन्दी'), ('vi', '🇻🇳 Tiếng Việt'),
  ];

  Future<void> _translateLastMessage() async {
    if (_messages.isEmpty) return;
    final lastAI = _messages.reversed.firstWhere((m) => !m.isUser,
        orElse: () => _messages.last);
    try {
      final encoded = Uri.encodeComponent(lastAI.text);
      final res = await http.get(Uri.parse(
          'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=auto&tl=$_targetLang&dt=t&q=$encoded'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final translated = (data[0] as List).map((s) => s[0]).join('');
        _addMessage(translated, isUser: false, isTranslation: true);
        _speak(translated);
      }
    } catch (e) {
      _addMessage('번역 실패: $e', isUser: false);
    }
  }

  void _showLangPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('번역 언어 선택', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
          ),
          ...(_langOptions.map((l) => ListTile(
            title: Text(l.$2, style: const TextStyle(color: Colors.black87)),
            trailing: _targetLang == l.$1
                ? const Icon(Icons.check_circle, color: _kHeader, size: 20) : null,
            onTap: () {
              setState(() => _targetLang = l.$1);
              Navigator.pop(context);
              _translateLastMessage();
            },
          ))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── 녹음 ────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_recording) {
      await _ch.invokeMethod('stopRecording');
      await _ch.invokeMethod('stopForeground');
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
      _addMessage('API 키를 설정하세요 (상단 ⚙️)', isUser: false);
      return;
    }
    setState(() => _thinking = true);

    final history = _messages
        .where((m) => !m.isTranslation)
        .toList()
        .reversed.take(40).toList().reversed
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

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
        final reply = jsonDecode(res.body)['content'][0]['text'] as String;
        _addMessage(reply, isUser: false);
        _speak(reply);
      } else {
        _addMessage('API Error ${res.statusCode}', isUser: false);
      }
    } catch (e) {
      _addMessage('네트워크 오류: $e', isUser: false);
    }
    if (mounted) setState(() => _thinking = false);
  }

  void _addMessage(String text, {required bool isUser, bool isTranslation = false}) {
    setState(() {
      _messages.add(_Msg(text: text, isUser: isUser, time: DateTime.now(),
          isTranslation: isTranslation));
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // ── 대화 저장 ───────────────────────────────────────────────
  Future<void> _saveConversation() async {
    if (_messages.isEmpty) return;
    final dir = Directory('/sdcard/Download/ChronoCall');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/call_$ts.md');
    final buf = StringBuffer('# ChronoCall — $ts\n\n');
    for (final m in _messages) {
      final prefix = m.isUser ? '**나**' : (m.isTranslation ? '**번역**' : '**Claude**');
      buf.writeln('[${DateFormat('HH:mm:ss').format(m.time)}] $prefix: ${m.text}\n');
    }
    await file.writeAsString(buf.toString());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장됨: call_$ts.md'),
            backgroundColor: _kHeader),
      );
    }
  }

  // ── API 키 설정 ─────────────────────────────────────────────
  void _showSettings() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Claude API Key',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.black87, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'sk-ant-api03-...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true, fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('claude_api_key', ctrl.text.trim());
              setState(() => _apiKey = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('저장', style: TextStyle(color: _kHeader)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── BUILD ─────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════
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
            if (_thinking) _buildThinkingBar(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── 카톡 헤더 ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _kHeader,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // AI 프로필
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: const Text('🧑‍🎓', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Claude Scholar',
                    style: TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Row(children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _recording ? Colors.redAccent :
                             _speaking ? Colors.orangeAccent :
                             _listening ? Colors.greenAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _recording ? 'REC' :
                    _thinking ? 'thinking...' :
                    _speaking ? 'speaking...' :
                    _listening ? 'listening...' : 'online',
                    style: TextStyle(color: Colors.white.withOpacity(0.7),
                        fontSize: 11),
                  ),
                ]),
              ],
            ),
          ),
          // 녹음
          IconButton(
            icon: Icon(_recording ? Icons.stop_circle_outlined : Icons.radio_button_checked,
                color: _recording ? Colors.redAccent : Colors.white.withOpacity(0.7), size: 22),
            onPressed: _toggleRecording,
          ),
          // 저장
          IconButton(
            icon: Icon(Icons.bookmark_border,
                color: Colors.white.withOpacity(0.7), size: 22),
            onPressed: _saveConversation,
          ),
          // 설정
          IconButton(
            icon: Icon(Icons.more_vert,
                color: Colors.white.withOpacity(0.7), size: 22),
            onPressed: _showSettings,
          ),
        ],
      ),
    );
  }

  // ── 채팅 리스트 ──────────────────────────────────────────────
  Widget _buildChatList() {
    if (_messages.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('마이크 버튼을 눌러 대화를 시작하세요',
              style: TextStyle(color: Color(0xFF5A6B7D), fontSize: 13)),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final showDate = i == 0 || !_sameDay(_messages[i-1].time, msg.time);
        return Column(
          children: [
            if (showDate) _buildDateDivider(msg.time),
            _buildBubble(msg),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateDivider(DateTime d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(DateFormat('yyyy년 M월 d일 EEEE', 'ko').format(d),
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.isUser;
    final timeStr = DateFormat('HH:mm').format(msg.time);

    if (isUser) {
      // 내 메시지 (오른쪽, 노랑)
      return Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 50),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeStr, style: const TextStyle(color: _kTimeText, fontSize: 10)),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _kMyBubble,
                  borderRadius: BorderRadius.circular(14).copyWith(
                    topRight: const Radius.circular(4)),
                ),
                child: Text(msg.text,
                    style: const TextStyle(color: _kMyText, fontSize: 14, height: 1.4)),
              ),
            ),
          ],
        ),
      );
    } else {
      // AI 메시지 (왼쪽, 흰색, 프로필 아이콘)
      return Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 50),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _kHeader.withOpacity(0.15),
              child: Text(msg.isTranslation ? '🌐' : '🧑‍🎓',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.isTranslation ? '번역' : 'Claude Scholar',
                      style: const TextStyle(color: Color(0xFF5A6B7D),
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: msg.isTranslation
                                ? const Color(0xFFE8F5E9) : _kAIBubble,
                            borderRadius: BorderRadius.circular(14).copyWith(
                              topLeft: const Radius.circular(4)),
                          ),
                          child: Text(msg.text,
                              style: const TextStyle(color: _kAIText,
                                  fontSize: 14, height: 1.4)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(timeStr,
                          style: const TextStyle(color: _kTimeText, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── 실시간 STT 표시 ──────────────────────────────────────────
  Widget _buildPartialBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8, height: 8,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.green)),
          const SizedBox(width: 10),
          Expanded(child: Text(_partial,
              style: const TextStyle(color: Colors.green, fontSize: 13,
                  fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis, maxLines: 2)),
        ],
      ),
    );
  }

  Widget _buildThinkingBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent)),
          SizedBox(width: 10),
          Text('Claude가 생각 중...', style: TextStyle(color: _kAccent, fontSize: 12)),
        ],
      ),
    );
  }

  // ── 하단 바 (카톡 스타일) ──────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      color: _kBottomBar,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          // 번역 버튼
          IconButton(
            icon: const Icon(Icons.translate, color: Color(0xFF888888), size: 24),
            onPressed: _messages.isEmpty ? null : _showLangPicker,
          ),
          const SizedBox(width: 4),

          // 상태 텍스트 영역
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDDDDDD)),
              ),
              child: Text(
                _listening ? '듣고 있습니다...' :
                _speaking ? 'Claude가 말하는 중...' :
                _thinking ? 'Claude가 생각하는 중...' :
                '마이크 버튼을 눌러 말하기',
                style: TextStyle(
                  color: _listening ? Colors.green :
                         _speaking ? Colors.orange :
                         Colors.grey[500],
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // AI 말 끊기 버튼
          if (_speaking)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.orange, size: 28),
              onPressed: _stopSpeaking,
            ),

          // 마이크 버튼
          GestureDetector(
            onTap: _thinking ? null : (_listening ? _stopListening : _startListening),
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listening ? Colors.green :
                       _thinking ? Colors.grey[400] : _kHeader,
                boxShadow: _listening ? [
                  BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 12),
                ] : null,
              ),
              child: Icon(
                _listening ? Icons.mic : Icons.mic_none,
                color: Colors.white, size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isTranslation;
  const _Msg({required this.text, required this.isUser, required this.time,
      this.isTranslation = false});
}
