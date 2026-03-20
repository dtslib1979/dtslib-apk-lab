import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ── 다크 + 카톡 팔레트 ───────────────────────────────────────────
const _kBg        = Color(0xFF000000);  // 블랙 배경
const _kHeader    = Color(0xFF1C1C1E);  // 다크 헤더
const _kMyBubble  = Color(0xFFFFEB33);  // 카톡 노랑
const _kAIBubble  = Color(0xFF2C2C2E);  // 다크 AI 버블
const _kMyText    = Color(0xFF1A1A1A);  // 노랑 위 검정
const _kAIText    = Color(0xFFFFFFFF);  // 다크 위 흰색
const _kTimeText  = Color(0xFF8E8E93);
const _kBottomBar = Color(0xFF1C1C1E);
const _kAccent    = Color(0xFF0A84FF);
const _kCallGreen = Color(0xFF30D158);
const _kCallRed   = Color(0xFFFF453A);

const _systemPrompt = '''You are a world-class scholar and polymath.
The user is a curious non-specialist who tests hypotheses through conversation.
Respond in the same language the user speaks. Default: Korean.
Be precise, cite theories/scholars when relevant, help develop thinking step by step.
Keep it conversational — this is a phone call, not a lecture. Under 150 words per turn.''';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic>? scholar;
  final List<Map<String, dynamic>>? conferenceScholars;
  const ChatScreen({super.key, this.scholar, this.conferenceScholars});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _ch = MethodChannel('com.parksy.chronocall/voice');

  final _scrollCtrl = ScrollController();
  final _textCtrl   = TextEditingController();
  final _focusNode  = FocusNode();
  final _messages = <_Msg>[];
  final _ttsFiles = <String>[];

  // 학자 정보
  bool get _isConference => widget.conferenceScholars != null && widget.conferenceScholars!.length >= 2;
  String get _scholarName => _isConference
      ? widget.conferenceScholars!.map((s) => s['nameKr'] ?? s['name']).join(' · ')
      : (widget.scholar?['nameKr'] ?? widget.scholar?['name'] ?? 'AI Scholar');
  String get _scholarEmoji => widget.scholar?['emoji'] ?? '🧑‍🎓';
  String get _scholarPrompt {
    if (_isConference) {
      final scholars = widget.conferenceScholars!;
      final names = scholars.map((s) => s['name']).join(', ');
      final prompts = scholars.map((s) =>
          '- ${s['name']}: ${s['prompt']}').join('\n');
      return 'This is a conference call with $names.\n'
          'The user is the moderator. When they address a specific scholar by name, respond AS that scholar.\n'
          'When scholars disagree, they should debate each other.\n'
          'Each scholar maintains their unique perspective and speaking style.\n'
          'Prefix each response with the scholar\'s name in brackets like [Einstein]: ...\n\n'
          'Scholar personalities:\n$prompts';
    }
    return widget.scholar?['prompt'] ?? _systemPrompt;
  }
  String get _scholarPhone => widget.scholar?['phone'] ?? '070-0000-0000';

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
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
  }

  List<Map<String, String>> _apiKeys = [];
  int _activeKeyIndex = 0;

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final keysJson = prefs.getString('gemini_api_keys');
    if (keysJson != null) {
      final list = jsonDecode(keysJson) as List;
      _apiKeys = list.map((e) => Map<String, String>.from(e)).toList();
    }
    _activeKeyIndex = prefs.getInt('gemini_active_key') ?? 0;
    if (_activeKeyIndex >= _apiKeys.length) _activeKeyIndex = 0;
    setState(() => _apiKey = _apiKeys.isNotEmpty ? _apiKeys[_activeKeyIndex]['key'] : null);
  }

  void _switchToNextKey() {
    if (_apiKeys.length <= 1) return;
    _activeKeyIndex = (_activeKeyIndex + 1) % _apiKeys.length;
    _apiKey = _apiKeys[_activeKeyIndex]['key'];
    final name = _apiKeys[_activeKeyIndex]['name'] ?? 'Key';
    _addMessage('429 한도 초과 → $name 키로 전환', isUser: false, isSystem: true);
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
            _sendToLLM(text);
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
          // Buds Pro 1탭 → 통화 시작/End 토글
          _inCall ? _endCall() : _startCall();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _addMessage(text, isUser: true);
    _sendToLLM(text);
  }

  // ══════════════════════════════════════════════════════════
  // ── 통화 세션 제어 ─────────────────────────────────────────
  // ══════════════════════════════════════════════════════════
  Future<void> _startCall() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _addMessage('API 키를 먼저 설정하세요', isUser: false);
      return;
    }

    setState(() { _inCall = true; _callStart = DateTime.now(); });

    // ForegroundService 시작 (마이크 녹음 안 함 — 키보드 STT와 충돌)
    // AI 음성은 TTS MP3로 이미 저장됨 → 통화 종료 시 합성
    _ttsFiles.clear();
    try { await _ch.invokeMethod('startForeground'); } catch (_) {}

    // 통화 연결음 "뚜뚜뚜"
    await _playDialTone();
    await Future.delayed(const Duration(milliseconds: 800));

    // 인사 메시지
    if (_isConference) {
      final names = widget.conferenceScholars!.map((s) => s['nameKr'] ?? s['name']).join(', ');
      _addMessage('컨퍼런스 콜: $names', isUser: false, isSystem: true);
      await _speak('컨퍼런스 콜이 연결되었습니다. 사회를 시작하세요.');
    } else {
      _addMessage('$_scholarName 연결됨', isUser: false, isSystem: true);
      await _speak('안녕하세요, $_scholarName입니다. 무엇이든 물어보세요.');
    }
    // 키보드 자동 포커스 (삼성 키보드 🎤 바로 사용 가능)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _endCall() async {
    setState(() { _inCall = false; _listening = false; });

    // STT/TTS 정지
    try { await _ch.invokeMethod('stopSTT'); } catch (_) {}
    try { await _ch.invokeMethod('stopAudio'); } catch (_) {}
    try { await _ch.invokeMethod('stopTTS'); } catch (_) {}

    // TTS MP3 파일들 → 녹취록 폴더로 복사

    // 통화 End음
    await _playHangupTone();

    try { await _ch.invokeMethod('stopForeground'); } catch (_) {}

    // 통화 시간 계산
    final duration = _callStart != null
        ? DateTime.now().difference(_callStart!) : Duration.zero;
    final durStr = '${duration.inMinutes}분 ${duration.inSeconds % 60}초';

    _addMessage('📞 통화 종료 ($durStr)', isUser: false, isSystem: true);

    // 자동 저장: 마크다운 + TTS 음성 파일
    await _saveCallData();
  }

  Future<void> _saveCallData() async {
    if (_messages.isEmpty) return;
    final dir = Directory('/sdcard/Download/ChronoCall');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateFormat('yyyyMMdd_HHmmss').format(_callStart ?? DateTime.now());
    final baseName = 'call_$ts';

    // 마크다운 저장
    final mdFile = File('${dir.path}/$baseName.md');
    final buf = StringBuffer('# ChronoCall — $_scholarName — $ts\n\n');
    for (final m in _messages) {
      final prefix = m.isUser ? '**나**' :
          m.isSystem ? '**시스템**' :
          m.isTranslation ? '**번역**' : '**$_scholarName**';
      buf.writeln('[${DateFormat('HH:mm:ss').format(m.time)}] $prefix: ${m.text}\n');
    }
    await mdFile.writeAsString(buf.toString());

    // TTS MP3 파일들 합쳐서 저장 (AI 음성 기록)
    if (_ttsFiles.isNotEmpty) {
      // 첫 번째 파일만 대표로 저장 (전체 합성은 FFmpeg 필요 — 향후)
      // 모든 TTS 파일을 순번으로 저장
      for (int i = 0; i < _ttsFiles.length; i++) {
        final src = File(_ttsFiles[i]);
        if (await src.exists()) {
          final dest = '${dir.path}/${baseName}_voice_${(i+1).toString().padLeft(2,'0')}.mp3';
          await src.copy(dest);
        }
      }
      _ttsFiles.clear();
    }

    if (mounted) {
      final voiceCount = _ttsFiles.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장됨: $baseName.md + 음성 ${voiceCount > 0 ? voiceCount : 0}개'),
            backgroundColor: _kCallGreen));
    }
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

  // ── Edge TTS 설정 ─────────────────────────────────────────
  static const _voiceOptions = [
    ('ko-KR-SunHiNeural', '선희 (여)'),
    ('ko-KR-InJoonNeural', '인준 (남)'),
    ('ko-KR-BongJinNeural', '봉진 (남)'),
    ('ko-KR-SeoHyeonNeural', '서현 (여)'),
    ('ko-KR-YuJinNeural', '유진 (여)'),
  ];
  static const _voiceOptionsEn = [
    ('en-US-AriaNeural', 'Aria (F)'),
    ('en-US-GuyNeural', 'Guy (M)'),
    ('en-US-JennyNeural', 'Jenny (F)'),
    ('en-US-DavisNeural', 'Davis (M)'),
  ];
  String _selectedVoiceKo = 'ko-KR-InJoonNeural';
  String _selectedVoiceEn = 'en-US-GuyNeural';
  double _speechRate = 1.0; // 0.5 ~ 2.0

  String get _edgeVoiceKo => _selectedVoiceKo;
  String get _edgeVoiceEn => _selectedVoiceEn;

  // 마크다운 기호 제거 (TTS용)
  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')  // **bold**
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')       // *italic*
        .replaceAll(RegExp(r'#+\s*'), '')                 // ### heading
        .replaceAll(RegExp(r'[-•]\s'), '')                // - bullet
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1') // [link](url)
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')         // `code`
        .trim();
  }

  Future<void> _speak(String text) async {
    if (!mounted) return;
    setState(() => _speaking = true);
    try {
      final cleanText = _stripMarkdown(text);
      final voice = RegExp(r'[가-힣]').hasMatch(cleanText) ? _edgeVoiceKo : _edgeVoiceEn;
      final escaped = cleanText
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');
      final rateStr = '${(_speechRate * 100).round()}%';
      final ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ko-KR">'
          '<voice name="$voice"><prosody rate="$rateStr">$escaped</prosody></voice></speak>';

      final res = await http.post(
        Uri.parse('https://eastus.tts.speech.microsoft.com/cognitiveservices/v1'),
        headers: {
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-32kbitrate-mono-mp3',
          'User-Agent': 'edge-tts-android',
        },
        body: ssml,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && res.bodyBytes.length > 1000) {
        final tmp = await getTemporaryDirectory();
        final path = '${tmp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        await File(path).writeAsBytes(res.bodyBytes);
        _ttsFiles.add(path);
        await _ch.invokeMethod('playAudio', {'path': path});
        return; // playAudio → onTTSDone 콜백이 speaking=false 처리
      }
    } catch (_) {}
    // Edge TTS 실패 → Android TTS fallback
    try {
      await _ch.invokeMethod('speak', {'text': text});
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
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

  // ── Gemini API (무료, 429 재시도) ──────────────────────────────
  static const _models = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  Future<void> _sendToLLM(String userText) async {
    if (_apiKey == null || _apiKey!.isEmpty) return;
    setState(() => _thinking = true);

    final history = _messages
        .where((m) => !m.isTranslation && !m.isSystem)
        .toList().reversed.take(20).toList().reversed
        .map((m) => {
          'role': m.isUser ? 'user' : 'model',
          'parts': [{'text': m.text}],
        }).toList();

    final body = jsonEncode({
      'system_instruction': {'parts': [{'text': '$_scholarPrompt\nRULES: Respond in user language (default Korean). Under 50 words. Core terms only from your own works. Your era diction. No markdown. No modern slang.'}]},
      'contents': history,
      'generationConfig': {'maxOutputTokens': 1024},
    });

    // 모델 fallback + 429 재시도
    for (final model in _models) {
      for (int retry = 0; retry < 3; retry++) {
        try {
          final res = await http.post(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
                '$model:generateContent?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          ).timeout(const Duration(seconds: 30));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final reply = candidates[0]['content']['parts'][0]['text'] as String;
              _addMessage(reply, isUser: false);
              await _speak(reply);
              if (mounted) setState(() => _thinking = false);
              return;
            }
          } else if (res.statusCode == 429) {
            // 429 → 다른 키로 스위칭
            if (_apiKeys.length > 1) {
              _switchToNextKey();
            } else {
              _addMessage('429 한도 초과 — 다른 계정 키를 추가하세요', isUser: false, isSystem: true);
            }
            await Future.delayed(Duration(seconds: 2 * (retry + 1)));
            continue;
          } else {
            _addMessage('API $model ${res.statusCode}', isUser: false);
            if (mounted) setState(() => _thinking = false);
            return;
          }
        } catch (e) {
          if (retry == 2) {
            _addMessage('네트워크 오류', isUser: false);
          }
        }
      }
    }
    if (mounted) setState(() { _thinking = false; _speaking = false; });
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

  // ── 대화 Save ───────────────────────────────────────────────
  Future<void> _saveConversation() async {
    if (_messages.isEmpty) return;
    final dir = Directory('/sdcard/Download/ChronoCall');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/call_$ts.md');
    final buf = StringBuffer('# ChronoCall — $ts\n\n');
    for (final m in _messages) {
      final prefix = m.isUser ? '**Me**' :
          m.isSystem ? '**System**' :
          m.isTranslation ? '**Translated**' : '**Claude**';
      buf.writeln('[${DateFormat('HH:mm:ss').format(m.time)}] $prefix: ${m.text}\n');
    }
    await file.writeAsString(buf.toString());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장됨: call_$ts.md'), backgroundColor: _kHeader));
    }
  }

  // ── 음성 설정 ──────────────────────────────────────────────
  void _showVoiceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('음성 설정', style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              // 한국어 성우
              const Text('한국어 성우', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8,
                children: _voiceOptions.map((v) {
                  final sel = _selectedVoiceKo == v.$1;
                  return GestureDetector(
                    onTap: () { setState(() => _selectedVoiceKo = v.$1); setSheet(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _kAccent.withOpacity(0.2) : const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? _kAccent : Colors.transparent)),
                      child: Text(v.$2, style: TextStyle(
                          color: sel ? _kAccent : Colors.white, fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 영어 성우
              const Text('English Voice', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8,
                children: _voiceOptionsEn.map((v) {
                  final sel = _selectedVoiceEn == v.$1;
                  return GestureDetector(
                    onTap: () { setState(() => _selectedVoiceEn = v.$1); setSheet(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _kAccent.withOpacity(0.2) : const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? _kAccent : Colors.transparent)),
                      child: Text(v.$2, style: TextStyle(
                          color: sel ? _kAccent : Colors.white, fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // 속도
              Row(children: [
                const Text('속도', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const Spacer(),
                Text('${_speechRate.toStringAsFixed(1)}x',
                    style: TextStyle(color: _kAccent, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              Slider(
                value: _speechRate,
                min: 0.5, max: 2.0, divisions: 6,
                activeColor: _kAccent,
                inactiveColor: const Color(0xFF2C2C2E),
                onChanged: (v) { setState(() => _speechRate = v); setSheet(() {}); },
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0.5x', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  Text('1.0x', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  Text('2.0x', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                ]),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── API 키 설정 ─────────────────────────────────────────────
  void _showSettings() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Gemini API 키',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.black87, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'AIzaSy...',
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
              await prefs.setString('gemini_api_key', ctrl.text.trim());
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
          CircleAvatar(radius: 18, backgroundColor: Colors.white.withOpacity(0.9),
            child: Text(_scholarEmoji, style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_scholarName,
                  style: TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Row(children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _inCall ? _kCallGreen : Colors.grey)),
                const SizedBox(width: 5),
                Text(
                  _inCall ? '통화 중 $durStr' :
                  '학자 핫라인  v3.7',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
              ]),
            ],
          )),
          IconButton(icon: Icon(Icons.translate,
              color: Colors.white.withOpacity(0.7), size: 22),
            onPressed: _messages.isEmpty ? null : _showLangPicker),
          IconButton(icon: Icon(Icons.save,
              color: Colors.white.withOpacity(0.7), size: 22),
            onPressed: _saveCallData,
            tooltip: '중간 저장'),
          IconButton(icon: Icon(Icons.record_voice_over,
              color: Colors.white.withOpacity(0.7), size: 22),
            onPressed: _showVoiceSettings),
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
          Text('이어버드 1탭으로 시작',
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
              child: Text(msg.isTranslation ? '🌐' : _scholarEmoji,
                  style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 6),
            Flexible(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg.isTranslation ? '번역' : _scholarName,
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
        Text('생각 중...', style: TextStyle(color: _kAccent, fontSize: 12)),
      ]),
    );
  }

  // ── 하단 바 ──────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      color: _kBottomBar,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: _inCall ? _buildInCallBar() : _buildIdleBar(),
    );
  }

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
        Text('전화', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  // 통화 중: 카톡 스타일 입력창 + 전송 + 종료
  Widget _buildInCallBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 상태 표시
        if (_thinking || _speaking)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 10, height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5,
                        color: _thinking ? _kAccent : Colors.orange)),
                const SizedBox(width: 8),
                Text(_thinking ? '생각 중...' : '말하는 중...',
                    style: TextStyle(color: _thinking ? _kAccent : Colors.orange, fontSize: 11)),
                if (_speaking) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _stopSpeaking,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.5))),
                      child: const Text('정지', style: TextStyle(color: Colors.orange, fontSize: 10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        // 입력창 + 전송 + 종료
        Row(
          children: [
            // 종료 버튼
            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kCallRed.withOpacity(0.15),
                ),
                child: Icon(Icons.call_end, color: _kCallRed, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            // 텍스트 입력 (삼성 키보드 마이크 사용)
            Expanded(
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                style: const TextStyle(color: _kAIText, fontSize: 14),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: '키보드 마이크(🎤)로 말하기...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                  filled: true,
                  fillColor: _kAIBubble,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 전송 버튼
            GestureDetector(
              onTap: _sendText,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccent,
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              ),
            ),
          ],
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
