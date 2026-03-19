import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ── 카톡 팔레트 ─────────────────────────────────────────────────
const _kBg        = Color(0xFF9BBBD4);
const _kHeader    = Color(0xFF3B4890);
const _kMyBubble  = Color(0xFFFFEB33);
const _kAIBubble  = Color(0xFFFFFFFF);
const _kMyText    = Color(0xFF1A1A1A);
const _kAIText    = Color(0xFF1A1A1A);
const _kTimeText  = Color(0xFF6B7B8D);
const _kBottomBar = Color(0xFFEFEFEF);
const _kAccent    = Color(0xFF4FC3F7);
const _kCallGreen = Color(0xFF4CAF50);
const _kCallRed   = Color(0xFFE53935);

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
  final _ttsFiles = <String>[];  // AI TTS MP3 경로 (나중에 합성용)

  bool _listening = false;
  bool _thinking  = false;
  bool _speaking  = false;
  String _partial = '';
  String? _apiKey;

  // ── 통화 세션 ──────────────────────────────────────────────
  bool _inCall    = false;
  DateTime? _callStart;

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
          if (mounted) setState(() { _listening = false; _partial = ''; });
          if (text.isNotEmpty && mounted) {
            _addMessage(text, isUser: true);
            _sendToClaude(text);
          } else if (_inCall) {
            // 아무 말 안 했으면 다시 듣기
            await Future.delayed(const Duration(milliseconds: 500));
            if (_inCall && mounted) _startListening();
          }
        case 'onSTTError':
          if (mounted) setState(() { _listening = false; _partial = ''; });
          // 에러나도 통화 중이면 다시 시도
          if (_inCall) {
            await Future.delayed(const Duration(seconds: 1));
            if (_inCall && mounted) _startListening();
          }
        case 'onTTSDone':
          if (mounted) setState(() => _speaking = false);
          // AI 말 끝 → 자동으로 내 턴 (삐 소리 + 마이크 ON)
          if (_inCall && mounted) {
            await _playBeep();
            await Future.delayed(const Duration(milliseconds: 300));
            if (_inCall && mounted) _startListening();
          }
        case 'onMediaButton':
          // Buds Pro 1탭 → 통화 시작/종료 토글
          _inCall ? _endCall() : _startCall();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // ── 통화 세션 제어 ─────────────────────────────────────────
  // ══════════════════════════════════════════════════════════
  Future<void> _startCall() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _addMessage('⚠️ API 키를 먼저 설정하세요', isUser: false);
      return;
    }

    setState(() { _inCall = true; _callStart = DateTime.now(); });

    // ForegroundService + 녹음 시작
    try { await _ch.invokeMethod('startForeground'); } catch (_) {}
    try { await _ch.invokeMethod('startRecording'); } catch (_) {}

    // 통화 연결음 "뚜뚜뚜"
    await _playDialTone();
    await Future.delayed(const Duration(milliseconds: 800));

    // 인사 메시지
    _addMessage('통화가 연결되었습니다. 무엇이든 물어보세요.', isUser: false);
    await _speak('안녕하세요, 무엇이든 물어보세요.');
  }

  Future<void> _endCall() async {
    setState(() { _inCall = false; _listening = false; });

    // STT/TTS 정지
    try { await _ch.invokeMethod('stopSTT'); } catch (_) {}
    try { await _ch.invokeMethod('stopAudio'); } catch (_) {}
    try { await _ch.invokeMethod('stopTTS'); } catch (_) {}

    // 통화 종료음
    await _playHangupTone();

    // 녹음 정지
    try { await _ch.invokeMethod('stopRecording'); } catch (_) {}
    try { await _ch.invokeMethod('stopForeground'); } catch (_) {}

    // 통화 시간 계산
    final duration = _callStart != null
        ? DateTime.now().difference(_callStart!) : Duration.zero;
    final durStr = '${duration.inMinutes}분 ${duration.inSeconds % 60}초';

    _addMessage('📞 통화 종료 ($durStr)', isUser: false, isSystem: true);

    // 자동 저장
    await _saveConversation();
  }

  // ── 효과음 (MethodChannel로 Kotlin 재생) ──────────────────
  Future<void> _playBeep() async {
    try { await _ch.invokeMethod('playTone', {'type': 'beep'}); } catch (_) {}
  }

  Future<void> _playDialTone() async {
    try { await _ch.invokeMethod('playTone', {'type': 'dial'}); } catch (_) {}
  }

  Future<void> _playHangupTone() async {
    try { await _ch.invokeMethod('playTone', {'type': 'hangup'}); } catch (_) {}
  }

  // ── STT ──────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (_thinking || _speaking || _listening) return;
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

  // ── Edge TTS ──────────────────────────────────────────────
  static const _edgeVoiceKo = 'ko-KR-SunHiNeural';
  static const _edgeVoiceEn = 'en-US-AriaNeural';

  Future<void> _speak(String text) async {
    setState(() => _speaking = true);
    try {
      final voice = RegExp(r'[가-힣]').hasMatch(text) ? _edgeVoiceKo : _edgeVoiceEn;
      final escaped = text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
      final ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ko-KR">'
          '<voice name="$voice">$escaped</voice></speak>';

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
        _ttsFiles.add(path);
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
    final lastAI = _messages.reversed.firstWhere((m) => !m.isUser && !m.isSystem,
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
        if (_inCall) _speak(translated);
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16),
            child: Text('번역 언어', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700, color: Colors.black87))),
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

  // ── Claude API ──────────────────────────────────────────────
  Future<void> _sendToClaude(String userText) async {
    if (_apiKey == null || _apiKey!.isEmpty) return;
    setState(() => _thinking = true);

    final history = _messages
        .where((m) => !m.isTranslation && !m.isSystem)
        .toList().reversed.take(40).toList().reversed
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
        await _speak(reply);
      } else {
        _addMessage('API Error ${res.statusCode}', isUser: false);
        if (mounted) setState(() => _speaking = false);
      }
    } catch (e) {
      _addMessage('네트워크 오류', isUser: false);
      if (mounted) setState(() => _speaking = false);
    }
    if (mounted) setState(() => _thinking = false);
  }

  void _addMessage(String text, {required bool isUser,
      bool isTranslation = false, bool isSystem = false}) {
    setState(() {
      _messages.add(_Msg(text: text, isUser: isUser, time: DateTime.now(),
          isTranslation: isTranslation, isSystem: isSystem));
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
      final prefix = m.isUser ? '**나**' :
          m.isSystem ? '**시스템**' :
          m.isTranslation ? '**번역**' : '**Claude**';
      buf.writeln('[${DateFormat('HH:mm:ss').format(m.time)}] $prefix: ${m.text}\n');
    }
    await file.writeAsString(buf.toString());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장: call_$ts.md'), backgroundColor: _kHeader));
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

  Widget _buildHeader() {
    final callDur = _inCall && _callStart != null
        ? DateTime.now().difference(_callStart!) : Duration.zero;
    final durStr = _inCall
        ? '${callDur.inMinutes.toString().padLeft(2,'0')}:${(callDur.inSeconds%60).toString().padLeft(2,'0')}'
        : '';

    return Container(
      color: _kHeader,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: Colors.white,
            child: const Text('🧑‍🎓', style: TextStyle(fontSize: 20))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Claude Scholar',
                  style: TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Row(children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _inCall ? _kCallGreen : Colors.grey)),
                const SizedBox(width: 5),
                Text(
                  _inCall ? '통화 중 $durStr' :
                  'AI Scholar Hotline  v3.0',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
              ]),
            ],
          )),
          IconButton(icon: Icon(Icons.translate,
              color: Colors.white.withOpacity(0.7), size: 22),
            onPressed: _messages.isEmpty ? null : _showLangPicker),
          IconButton(icon: Icon(Icons.bookmark_border,
              color: Colors.white.withOpacity(0.7), size: 22),
            onPressed: _saveConversation),
          IconButton(icon: Icon(Icons.more_vert,
              color: Colors.white.withOpacity(0.7), size: 22),
            onPressed: _showSettings),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty && !_inCall) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📞', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          const Text('전화 버튼을 눌러 통화 시작',
              style: TextStyle(color: Color(0xFF5A6B7D), fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('이어버드 1탭으로도 시작 가능',
              style: TextStyle(color: const Color(0xFF5A6B7D).withOpacity(0.6),
                  fontSize: 12)),
          const SizedBox(height: 24),
          Text('화면을 보지 않아도 됩니다',
              style: TextStyle(color: const Color(0xFF5A6B7D).withOpacity(0.4),
                  fontSize: 11)),
        ],
      ));
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final showDate = i == 0 || !_sameDay(_messages[i-1].time, msg.time);
        return Column(children: [
          if (showDate) _buildDateDivider(msg.time),
          if (msg.isSystem) _buildSystemMsg(msg)
          else _buildBubble(msg),
        ]);
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
          borderRadius: BorderRadius.circular(12)),
        child: Text(DateFormat('yyyy-MM-dd').format(d),
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }

  Widget _buildSystemMsg(_Msg msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12)),
        child: Text(msg.text, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5A6B7D), fontSize: 11)),
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.isUser;
    final timeStr = DateFormat('HH:mm').format(msg.time);

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 50),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeStr, style: const TextStyle(color: _kTimeText, fontSize: 10)),
            const SizedBox(width: 6),
            Flexible(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: _kMyBubble,
                borderRadius: BorderRadius.circular(14).copyWith(
                    topRight: const Radius.circular(4))),
              child: Text(msg.text,
                  style: const TextStyle(color: _kMyText, fontSize: 14, height: 1.4)),
            )),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 50),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 16,
              backgroundColor: _kHeader.withOpacity(0.15),
              child: Text(msg.isTranslation ? '🌐' : '🧑‍🎓',
                  style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 6),
            Flexible(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg.isTranslation ? '번역' : 'Claude Scholar',
                    style: const TextStyle(color: Color(0xFF5A6B7D),
                        fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Flexible(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: msg.isTranslation ? const Color(0xFFE8F5E9) : _kAIBubble,
                      borderRadius: BorderRadius.circular(14).copyWith(
                          topLeft: const Radius.circular(4))),
                    child: Text(msg.text,
                        style: const TextStyle(color: _kAIText, fontSize: 14, height: 1.4)),
                  )),
                  const SizedBox(width: 6),
                  Text(timeStr, style: const TextStyle(color: _kTimeText, fontSize: 10)),
                ]),
              ],
            )),
          ],
        ),
      );
    }
  }

  Widget _buildPartialBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const SizedBox(width: 8, height: 8,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.green)),
        const SizedBox(width: 10),
        Expanded(child: Text(_partial,
            style: const TextStyle(color: Colors.green, fontSize: 13,
                fontStyle: FontStyle.italic),
            overflow: TextOverflow.ellipsis, maxLines: 2)),
      ]),
    );
  }

  Widget _buildThinkingBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14)),
      child: const Row(children: [
        SizedBox(width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent)),
        SizedBox(width: 10),
        Text('Claude가 생각 중...', style: TextStyle(color: _kAccent, fontSize: 12)),
      ]),
    );
  }

  // ── 하단 바: 통화 시작/종료 중심 ──────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      color: _kBottomBar,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: _inCall ? _buildInCallBar() : _buildIdleBar(),
    );
  }

  // 대기 상태: 큰 전화 버튼
  Widget _buildIdleBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _startCall,
          child: Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kCallGreen,
              boxShadow: [BoxShadow(color: _kCallGreen.withOpacity(0.4), blurRadius: 16)],
            ),
            child: const Icon(Icons.call, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text('전화 걸기', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  // 통화 중: 마이크 상태 + 끊기 버튼
  Widget _buildInCallBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // AI 말 끊기
        if (_speaking)
          GestureDetector(
            onTap: _stopSpeaking,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 50, height: 50,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.15),
                  border: Border.all(color: Colors.orange)),
                child: const Icon(Icons.stop, color: Colors.orange, size: 24)),
              const SizedBox(height: 4),
              const Text('끊기', style: TextStyle(color: Colors.orange, fontSize: 10)),
            ]),
          ),

        // 마이크 상태 표시 (자동이라 누를 필요 없음)
        Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _listening ? Colors.green :
                     _thinking ? Colors.blue.withOpacity(0.3) :
                     _speaking ? Colors.orange.withOpacity(0.3) :
                     Colors.grey.withOpacity(0.2)),
            child: Icon(
              _listening ? Icons.mic :
              _thinking ? Icons.psychology :
              _speaking ? Icons.volume_up : Icons.mic_off,
              color: _listening ? Colors.white :
                     _thinking ? Colors.blue : Colors.grey,
              size: 28)),
          const SizedBox(height: 4),
          Text(
            _listening ? '듣는 중' :
            _thinking ? '생각 중' :
            _speaking ? '말하는 중' : '대기',
            style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ]),

        // 통화 종료
        GestureDetector(
          onTap: _endCall,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _kCallRed,
                boxShadow: [BoxShadow(color: _kCallRed.withOpacity(0.4), blurRadius: 12)]),
              child: const Icon(Icons.call_end, color: Colors.white, size: 28)),
            const SizedBox(height: 4),
            const Text('종료', style: TextStyle(color: _kCallRed, fontSize: 10)),
          ]),
        ),
      ],
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isTranslation;
  final bool isSystem;
  const _Msg({required this.text, required this.isUser, required this.time,
      this.isTranslation = false, this.isSystem = false});
}
