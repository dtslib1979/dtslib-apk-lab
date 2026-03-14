import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../core/constants.dart';

class InterpreterScreen extends StatefulWidget {
  const InterpreterScreen({super.key});

  @override
  State<InterpreterScreen> createState() => _InterpreterScreenState();
}

class _InterpreterScreenState extends State<InterpreterScreen> {
  final _stt = SpeechToText();
  OnDeviceTranslator? _translator;

  bool _sttReady = false;
  bool _translatorReady = false;
  bool _listening = false;

  String _original = '';
  String _interim = '';
  String _translated = '';
  String _status = '초기화 중...';
  String _srcLang = 'auto'; // STT locale

  static const _langMap = {
    'auto':  {'label': '🌍 자동', 'mlkit': null,                           'stt': ''},
    'en_US': {'label': 'EN',     'mlkit': TranslateLanguage.english,       'stt': 'en_US'},
    'ja_JP': {'label': 'JP',     'mlkit': TranslateLanguage.japanese,      'stt': 'ja_JP'},
    'zh_CN': {'label': 'ZH',     'mlkit': TranslateLanguage.chinese,       'stt': 'zh_CN'},
  };

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    // STT 초기화
    _sttReady = await _stt.initialize(
      onStatus: (s) { if ((s == 'done' || s == 'notListening') && _listening) _restartListen(); },
      onError: (e) { if (mounted) setState(() => _status = '오류: ${e.errorMsg}'); },
    );

    // ML Kit 번역기 초기화 (EN→KO 기본)
    try {
      final mgr = OnDeviceTranslatorModelManager();
      final enOk = await mgr.isModelDownloaded(TranslateLanguage.english);
      final koOk = await mgr.isModelDownloaded(TranslateLanguage.korean);
      if (!enOk) {
        if (mounted) setState(() => _status = 'EN 모델 다운로드 중...');
        await mgr.downloadModel(TranslateLanguage.english);
      }
      if (!koOk) {
        if (mounted) setState(() => _status = 'KO 모델 다운로드 중...');
        await mgr.downloadModel(TranslateLanguage.korean);
      }
      _translator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: TranslateLanguage.korean,
      );
      _translatorReady = true;
    } catch (_) {
      _translatorReady = false;
    }

    if (mounted) {
      setState(() => _status = _sttReady ? '대기 중' : '음성인식 미지원 기기');
    }
  }

  Future<void> _listen() async {
    if (!_sttReady) return;
    final locale = _langMap[_srcLang]!['stt'] as String;
    await _stt.listen(
      onResult: _onResult,
      localeId: locale.isEmpty ? '' : locale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
    );
    if (mounted) setState(() { _listening = true; _status = '🔴 인식 중...'; });
  }

  void _restartListen() {
    if (!_listening) return;
    Future.delayed(const Duration(milliseconds: 300), _listen);
  }

  void _onResult(SpeechRecognitionResult r) {
    if (r.finalResult) {
      final text = r.recognizedWords;
      if (text.isEmpty) return;
      setState(() { _original += '$text\n'; _interim = ''; });
      _translateText(text);
    } else {
      setState(() => _interim = r.recognizedWords);
    }
  }

  Future<void> _translateText(String text) async {
    if (_translatorReady && _translator != null) {
      try {
        final result = await _translator!.translateText(text);
        if (mounted) setState(() => _translated += '$result\n');
        return;
      } catch (_) {}
    }
    // 번역기 준비 안 됨 — 메시지만 표시
    if (mounted) setState(() => _translated = '(번역 모델 준비 중)');
  }

  Future<void> _stop() async {
    await _stt.stop();
    if (mounted) setState(() { _listening = false; _status = '대기 중'; _interim = ''; });
  }

  // 언어 변경 → translator 재생성 (Bug 2 fix)
  Future<void> _changeSrcLang(String newLang) async {
    if (_listening) await _stop();
    setState(() { _srcLang = newLang; _translated = ''; });

    final mlkitLang = _langMap[newLang]!['mlkit'] as TranslateLanguage?;
    _translator?.close();
    _translator = null;

    if (mlkitLang == null) {
      // auto 모드 — STT 자동 감지 + EN→KO 폴백 번역 유지 (#5 fix)
      final fallback = TranslateLanguage.english;
      final mgr = OnDeviceTranslatorModelManager();
      if (!await mgr.isModelDownloaded(fallback)) {
        setState(() => _status = 'EN 모델 다운로드 중...');
        await mgr.downloadModel(fallback);
      }
      if (!mounted) return;
      _translator = OnDeviceTranslator(
        sourceLanguage: fallback,
        targetLanguage: TranslateLanguage.korean,
      );
      setState(() { _translatorReady = true; _status = '대기 중 (자동 — EN→KO 폴백)'; });
      return;
    }

    setState(() => _status = '모델 확인 중...');
    try {
      final mgr = OnDeviceTranslatorModelManager();
      if (!await mgr.isModelDownloaded(mlkitLang)) {
        setState(() => _status = '$newLang 모델 다운로드 중...');
        await mgr.downloadModel(mlkitLang);
      }
      if (!mounted) return;
      _translator = OnDeviceTranslator(
        sourceLanguage: mlkitLang,
        targetLanguage: TranslateLanguage.korean,
      );
      setState(() { _translatorReady = true; _status = '대기 중'; });
    } catch (_) {
      if (mounted) setState(() { _translatorReady = false; _status = '모델 로드 실패'; });
    }
  }

  void _clear() => setState(() { _original = ''; _interim = ''; _translated = ''; });

  @override
  void dispose() {
    _stt.stop();
    _translator?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.kSurface,
        title: Text('동시통역', style: TextStyle(color: AppConstants.kAccent)),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
            onPressed: _clear,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 언어 선택
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _langMap.entries.map((e) {
              final sel = _srcLang == e.key;
              return GestureDetector(
                onTap: () => _changeSrcLang(e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppConstants.kAccent.withValues(alpha: 0.2) : AppConstants.kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppConstants.kAccent : AppConstants.kDim),
                  ),
                  child: Text(e.value['label'] as String,
                      style: TextStyle(color: sel ? AppConstants.kAccent : Colors.white54, fontSize: 13)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // 원문
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppConstants.kSurface, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('원문', style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 6),
                Expanded(child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_original, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6)),
                    if (_interim.isNotEmpty)
                      Text(_interim, style: const TextStyle(color: Colors.white38, fontStyle: FontStyle.italic)),
                  ]),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 8),

          // 번역
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppConstants.kSurface, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('한국어 번역', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(width: 8),
                  if (!_translatorReady)
                    const Text('(모델 다운로드 중)', style: TextStyle(color: Colors.white24, fontSize: 10)),
                ]),
                const SizedBox(height: 6),
                Expanded(child: SingleChildScrollView(
                  child: Text(_translated,
                      style: TextStyle(color: AppConstants.kAccent, fontSize: 16, height: 1.7, fontWeight: FontWeight.w500)),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 8),

          Text(_status, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 8),

          // 시작/중지
          ElevatedButton(
            onPressed: _sttReady ? (_listening ? _stop : _listen) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _listening ? Colors.red : AppConstants.kAccent,
              foregroundColor: _listening ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_listening ? '⏹ 중지' : '🎙 시작',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}
