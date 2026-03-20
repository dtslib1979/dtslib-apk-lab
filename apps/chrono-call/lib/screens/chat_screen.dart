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

// ── 통합 프리미엄 팔레트 ─────────────────────────────────────────
const _kBg        = Color(0xFF08080D);
const _kSurface   = Color(0xFF12121A);
const _kCard      = Color(0xFF161622);
const _kGlass     = Color(0x18FFFFFF);
const _kBorder    = Color(0xFF28283E);
const _kText      = Color(0xFFF2F2F7);
const _kTextSec   = Color(0xFF8E8EA0);
const _kTextDim   = Color(0xFF505068);
const _kAccent    = Color(0xFF64FFDA);
const _kBlue      = Color(0xFF5E7CFF);
const _kGreen     = Color(0xFF30D158);
const _kRed       = Color(0xFFFF453A);

// 버블 — 유저: 시안 글래스, AI: 다크 글래스
const _kUserBubble  = Color(0xFF1A3A3A);
const _kUserBorder  = Color(0xFF2A5A5A);
const _kAIBubble    = Color(0xFF1A1A28);
const _kAIBorder    = Color(0xFF2A2A40);

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

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
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

  bool _inCall    = false;
  DateTime? _callStart;

  // 타이머 갱신
  Timer? _callTimer;

  // 웨이브 애니메이션
  late final AnimationController _waveCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _initVoiceFromScholar();
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
    _addMessage('429 rate limit → switched to $name', isUser: false, isSystem: true);
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
            await Future.delayed(const Duration(milliseconds: 500));
            if (_inCall && mounted) _startListening();
          }
        case 'onSTTError':
          if (mounted) setState(() { _listening = false; _partial = ''; });
          if (_inCall) {
            await Future.delayed(const Duration(seconds: 1));
            if (_inCall && mounted) _startListening();
          }
        case 'onTTSDone':
          if (mounted) setState(() => _speaking = false);
          if (_inCall && mounted) {
            await _playBeep();
            await Future.delayed(const Duration(milliseconds: 300));
            if (_inCall && mounted) _startListening();
          }
        case 'onMediaButton':
          _inCall ? _endCall() : _startCall();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    _callTimer?.cancel();
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
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _ttsFiles.clear();
    try { await _ch.invokeMethod('startForeground'); } catch (_) {}

    await _playDialTone();
    await Future.delayed(const Duration(milliseconds: 800));

    if (_isConference) {
      final names = widget.conferenceScholars!.map((s) => s['nameKr'] ?? s['name']).join(', ');
      _addMessage('Conference: $names', isUser: false, isSystem: true);
      await _speak('컨퍼런스 콜이 연결되었습니다. 사회를 시작하세요.');
    } else {
      _addMessage('$_scholarName connected', isUser: false, isSystem: true);
      await _speak('안녕하세요, $_scholarName입니다. 무엇이든 물어보세요.');
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    setState(() { _inCall = false; _listening = false; });

    try { await _ch.invokeMethod('stopSTT'); } catch (_) {}
    try { await _ch.invokeMethod('stopAudio'); } catch (_) {}
    try { await _ch.invokeMethod('stopTTS'); } catch (_) {}

    await _playHangupTone();

    try { await _ch.invokeMethod('stopForeground'); } catch (_) {}

    final duration = _callStart != null
        ? DateTime.now().difference(_callStart!) : Duration.zero;
    final durStr = '${duration.inMinutes}m ${duration.inSeconds % 60}s';

    _addMessage('Call ended ($durStr)', isUser: false, isSystem: true);

    await _saveCallData();
  }

  Future<void> _saveCallData() async {
    if (_messages.isEmpty) return;
    final dir = Directory('/sdcard/Download/ChronoCall');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateFormat('yyyyMMdd_HHmmss').format(_callStart ?? DateTime.now());
    final baseName = 'call_$ts';

    final mdFile = File('${dir.path}/$baseName.md');
    final buf = StringBuffer('# ChronoCall — $_scholarName — $ts\n\n');
    for (final m in _messages) {
      final prefix = m.isUser ? '**나**' :
          m.isSystem ? '**시스템**' :
          m.isTranslation ? '**번역**' : '**$_scholarName**';
      buf.writeln('[${DateFormat('HH:mm:ss').format(m.time)}] $prefix: ${m.text}\n');
    }
    await mdFile.writeAsString(buf.toString());

    if (_ttsFiles.isNotEmpty) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $baseName.md'),
          backgroundColor: _kGreen.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _playBeep() async {
    try { await _ch.invokeMethod('playTone', {'type': 'beep'}); } catch (_) {}
  }

  Future<void> _playDialTone() async {
    try { await _ch.invokeMethod('playTone', {'type': 'dial'}); } catch (_) {}
  }

  Future<void> _playHangupTone() async {
    try { await _ch.invokeMethod('playTone', {'type': 'hangup'}); } catch (_) {}
  }

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
  late String _selectedVoiceKo;
  late String _selectedVoiceEn;
  double _speechRate = 1.0;

  void _initVoiceFromScholar() {
    final gender = widget.scholar?['voiceGender'] ?? 'male';
    _selectedVoiceKo = gender == 'female' ? 'ko-KR-SunHiNeural' : 'ko-KR-InJoonNeural';
    _selectedVoiceEn = gender == 'female' ? 'en-US-AriaNeural' : 'en-US-GuyNeural';
  }

  String get _edgeVoiceKo => _selectedVoiceKo;
  String get _edgeVoiceEn => _selectedVoiceEn;

  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'[-•]\s'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
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
        return;
      }
    } catch (_) {}
    try {
      final tmp = await getTemporaryDirectory();
      final path = '${tmp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _ch.invokeMethod('speakToFile', {'text': _stripMarkdown(text), 'path': path});
      _ttsFiles.add(path);
      await _ch.invokeMethod('speak', {'text': _stripMarkdown(text)});
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
      _addMessage('Translation failed: $e', isUser: false);
    }
  }

  void _showLangPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 8),
              child: Text('Translate', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w700, color: _kText))),
            ...(_langOptions.map((l) => ListTile(
              title: Text(l.$2, style: const TextStyle(color: _kText, fontSize: 14)),
              trailing: _targetLang == l.$1
                  ? Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: _kAccent),
                      child: const Icon(Icons.check, color: Colors.black, size: 12),
                    )
                  : null,
              onTap: () {
                setState(() => _targetLang = l.$1);
                Navigator.pop(context);
                _translateLastMessage();
              },
            ))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Gemini API ──────────────────────────────────────────────
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
            if (_apiKeys.length > 1) {
              _switchToNextKey();
            } else {
              _addMessage('429 rate limit — add another API key', isUser: false, isSystem: true);
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
            _addMessage('Network error', isUser: false);
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
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
  }

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
        SnackBar(
          content: Text('Saved: call_$ts.md'),
          backgroundColor: _kGreen.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── 음성 설정 ──────────────────────────────────────────────
  void _showVoiceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2)),
              )),
              const Text('Voice Settings', style: TextStyle(color: _kText,
                  fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              // 한국어 성우
              Text('한국어', style: TextStyle(color: _kTextSec, fontSize: 12,
                  fontWeight: FontWeight.w600, letterSpacing: 1)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                children: _voiceOptions.map((v) {
                  final sel = _selectedVoiceKo == v.$1;
                  return GestureDetector(
                    onTap: () { setState(() => _selectedVoiceKo = v.$1); setSheet(() {}); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? _kAccent.withOpacity(0.1) : _kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? _kAccent.withOpacity(0.4) : _kBorder)),
                      child: Text(v.$2, style: TextStyle(
                          color: sel ? _kAccent : _kTextSec, fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // 영어 성우
              Text('ENGLISH', style: TextStyle(color: _kTextSec, fontSize: 12,
                  fontWeight: FontWeight.w600, letterSpacing: 1)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                children: _voiceOptionsEn.map((v) {
                  final sel = _selectedVoiceEn == v.$1;
                  return GestureDetector(
                    onTap: () { setState(() => _selectedVoiceEn = v.$1); setSheet(() {}); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? _kAccent.withOpacity(0.1) : _kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? _kAccent.withOpacity(0.4) : _kBorder)),
                      child: Text(v.$2, style: TextStyle(
                          color: sel ? _kAccent : _kTextSec, fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // 속도
              Row(children: [
                Text('SPEED', style: TextStyle(color: _kTextSec, fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 1)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('${_speechRate.toStringAsFixed(1)}x',
                      style: TextStyle(color: _kAccent, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: _kAccent,
                  inactiveTrackColor: _kBorder,
                  thumbColor: _kAccent,
                  overlayColor: _kAccent.withOpacity(0.1),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: _speechRate,
                  min: 0.5, max: 2.0, divisions: 6,
                  onChanged: (v) { setState(() => _speechRate = v); setSheet(() {}); },
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0.5x', style: TextStyle(color: _kTextDim, fontSize: 10)),
                  Text('1.0x', style: TextStyle(color: _kTextDim, fontSize: 10)),
                  Text('2.0x', style: TextStyle(color: _kTextDim, fontSize: 10)),
                ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gemini API Key',
            style: TextStyle(color: _kText, fontWeight: FontWeight.w700, fontSize: 17)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: _kText, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'AIzaSy...',
            hintStyle: TextStyle(color: _kTextDim),
            filled: true, fillColor: _kSurface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _kAccent.withOpacity(0.5))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _kTextSec))),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('gemini_api_key', ctrl.text.trim());
              setState(() => _apiKey = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: _kAccent, fontWeight: FontWeight.w700)),
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
            if (_speaking) _buildSpeakingBar(),
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
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kBorder.withOpacity(0.3))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 아바타
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _kCard,
              border: Border.all(color: _kBorder.withOpacity(0.5)),
            ),
            child: Center(child: Text(_scholarEmoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_scholarName,
                  style: const TextStyle(color: _kText, fontSize: 15,
                      fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _inCall ? _kGreen : _kTextDim,
                    boxShadow: _inCall ? [
                      BoxShadow(color: _kGreen.withOpacity(0.5), blurRadius: 6),
                    ] : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _inCall ? 'In call  $durStr' : 'Scholar Hotline',
                  style: TextStyle(color: _kTextSec, fontSize: 11, letterSpacing: 0.3)),
              ]),
            ],
          )),
          _headerButton(Icons.translate, _messages.isEmpty ? null : _showLangPicker),
          _headerButton(Icons.save_outlined, _saveCallData),
          _headerButton(Icons.graphic_eq, _showVoiceSettings),
          _headerButton(Icons.more_vert, _showSettings),
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, VoidCallback? onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34, height: 34,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: _kGlass,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: onPressed != null ? _kTextSec : _kTextDim.withOpacity(0.3), size: 18),
      ),
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty && !_inCall) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kSurface,
                border: Border.all(color: _kBorder),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withOpacity(0.05 + _pulseCtrl.value * 0.05),
                    blurRadius: 20 + _pulseCtrl.value * 10,
                  ),
                ],
              ),
              child: const Icon(Icons.call, size: 36, color: _kAccent),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Press call to begin',
              style: TextStyle(color: _kTextSec, fontSize: 15,
                  fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Text('Or tap earbud once',
              style: TextStyle(color: _kTextDim, fontSize: 12)),
          const SizedBox(height: 20),
          Text('Hands-free conversation',
              style: TextStyle(color: _kTextDim.withOpacity(0.5),
                  fontSize: 11, letterSpacing: 0.5)),
        ],
      ));
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final showDate = i == 0 || !_sameDay(_messages[i-1].time, msg.time);
        return Column(children: [
          if (showDate) _buildDateDivider(msg.time),
          if (msg.isSystem) _buildSystemMsg(msg)
          else _buildBubble(msg, i),
        ]);
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateDivider(DateTime d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 0.5, color: _kBorder.withOpacity(0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(DateFormat('yyyy. MM. dd').format(d),
                style: TextStyle(color: _kTextDim, fontSize: 11, letterSpacing: 0.5)),
          ),
          Expanded(child: Container(height: 0.5, color: _kBorder.withOpacity(0.3))),
        ],
      ),
    );
  }

  Widget _buildSystemMsg(_Msg msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: _kGlass,
          borderRadius: BorderRadius.circular(16)),
        child: Text(msg.text, textAlign: TextAlign.center,
            style: TextStyle(color: _kTextSec, fontSize: 11, letterSpacing: 0.2)),
      ),
    );
  }

  Widget _buildBubble(_Msg msg, int index) {
    final isUser = msg.isUser;
    final timeStr = DateFormat('HH:mm').format(msg.time);

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeStr, style: TextStyle(color: _kTextDim, fontSize: 10)),
            const SizedBox(width: 8),
            Flexible(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kUserBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: _kUserBorder.withOpacity(0.4), width: 0.5),
                boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.03), blurRadius: 8)],
              ),
              child: Text(msg.text,
                  style: const TextStyle(color: _kText, fontSize: 14, height: 1.45,
                      letterSpacing: 0.1)),
            )),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: msg.isTranslation ? _kBlue.withOpacity(0.1) : _kCard,
                border: Border.all(color: _kBorder.withOpacity(0.4), width: 0.5),
              ),
              child: Center(child: Text(
                  msg.isTranslation ? '🌐' : _scholarEmoji,
                  style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 8),
            Flexible(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 4),
                  child: Text(msg.isTranslation ? 'Translation' : _scholarName,
                      style: TextStyle(color: _kTextDim, fontSize: 11,
                          fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Flexible(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg.isTranslation ? _kBlue.withOpacity(0.08) : _kAIBubble,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                          color: msg.isTranslation
                              ? _kBlue.withOpacity(0.15)
                              : _kAIBorder.withOpacity(0.4),
                          width: 0.5),
                    ),
                    child: Text(msg.text,
                        style: const TextStyle(color: _kText, fontSize: 14, height: 1.45,
                            letterSpacing: 0.1)),
                  )),
                  const SizedBox(width: 8),
                  Text(timeStr, style: TextStyle(color: _kTextDim, fontSize: 10)),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withOpacity(0.12)),
      ),
      child: Row(children: [
        // 웨이브 도트
        ...[0.0, 0.2, 0.4].map((delay) => AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) {
            final v = ((_waveCtrl.value + delay) % 1.0);
            final h = 4 + (v < 0.5 ? v : 1 - v) * 12;
            return Container(
              width: 3, height: h,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.7),
                borderRadius: BorderRadius.circular(2)),
            );
          },
        )),
        const SizedBox(width: 8),
        Expanded(child: Text(_partial,
            style: TextStyle(color: _kGreen.withOpacity(0.8), fontSize: 13,
                fontStyle: FontStyle.italic),
            overflow: TextOverflow.ellipsis, maxLines: 2)),
      ]),
    );
  }

  Widget _buildThinkingBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBlue.withOpacity(0.12)),
      ),
      child: Row(children: [
        SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: _kBlue.withOpacity(0.6))),
        const SizedBox(width: 12),
        Text('Thinking...', style: TextStyle(color: _kBlue.withOpacity(0.7), fontSize: 12,
            letterSpacing: 0.3)),
      ]),
    );
  }

  Widget _buildSpeakingBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccent.withOpacity(0.12)),
      ),
      child: Row(children: [
        // 웨이브 바
        ...[0.0, 0.15, 0.3, 0.45, 0.6].map((delay) => AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) {
            final v = ((_waveCtrl.value + delay) % 1.0);
            final h = 6 + (v < 0.5 ? v : 1 - v) * 16;
            return Container(
              width: 2.5, height: h,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2)),
            );
          },
        )),
        const SizedBox(width: 10),
        Text('Speaking...', style: TextStyle(color: _kAccent.withOpacity(0.7), fontSize: 12,
            letterSpacing: 0.3)),
        const Spacer(),
        GestureDetector(
          onTap: _stopSpeaking,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kAccent.withOpacity(0.2)),
            ),
            child: Text('Stop', style: TextStyle(color: _kAccent, fontSize: 11,
                fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ── 하단 바 ──────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder.withOpacity(0.3), width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(12, 10, 12,
          MediaQuery.of(context).padding.bottom + 10),
      child: _inCall ? _buildInCallBar() : _buildIdleBar(),
    );
  }

  Widget _buildIdleBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kGreen.withOpacity(0.1 + _pulseCtrl.value * 0.15),
                  blurRadius: 20 + _pulseCtrl.value * 12,
                  spreadRadius: _pulseCtrl.value * 3,
                ),
              ],
            ),
            child: child,
          ),
          child: GestureDetector(
            onTap: _startCall,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFF30D158), Color(0xFF25A84A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: const Icon(Icons.call, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Call', style: TextStyle(color: _kTextDim, fontSize: 12,
            fontWeight: FontWeight.w500, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildInCallBar() {
    return Row(
      children: [
        // 종료
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kRed.withOpacity(0.12),
              border: Border.all(color: _kRed.withOpacity(0.2)),
            ),
            child: Icon(Icons.call_end, color: _kRed, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        // 입력
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kBorder.withOpacity(0.4)),
            ),
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              style: const TextStyle(color: _kText, fontSize: 14),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(
                hintText: 'Type or use mic...',
                hintStyle: TextStyle(color: _kTextDim, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 전송
        GestureDetector(
          onTap: _sendText,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [_kAccent, _kBlue],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.2), blurRadius: 8)],
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 22),
          ),
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
