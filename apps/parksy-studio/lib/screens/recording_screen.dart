import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/recording_service.dart';
import 'trimmer_screen.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});
  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  String _format = 'shorts';
  AudioMode _audioMode = AudioMode.mic;
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  static const _formats = [
    {'id': 'shorts', 'label': 'Shorts', 'desc': '1080×1920  9:16', 'icon': '📱'},
    {'id': 'long',   'label': 'Long',   'desc': '1920×1080  16:9', 'icon': '🖥️'},
  ];

  static const _audioModes = [
    {
      'mode': AudioMode.mic,
      'label': '🎙 기본 마이크',
      'desc': 'AGC 적용, 일반 마이크용',
    },
    {
      'mode': AudioMode.unprocessed,
      'label': '🎤 외장 마이크 원본',
      'desc': 'AGC/노이즈게이트 우회\nShure MOTIV USB 권장',
    },
    {
      'mode': AudioMode.daw,
      'label': '🎛 DAW 믹스 캡처',
      'desc': '시스템 오디오 전체 캡처\nBGM + DAW 처리 목소리 믹싱',
    },
  ];

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) RecordingService.stop();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await RecordingService.stop();
      _timer?.cancel();
      setState(() { _recording = false; });
      if (path != null && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TrimmerScreen(videoPath: path, format: _format),
        ));
      }
    } else {
      final path = await RecordingService.start(format: _format, audioMode: _audioMode);
      if (path != null) {
        setState(() { _recording = true; _seconds = 0; });
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _seconds++);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('화면녹화 권한이 필요합니다')),
          );
        }
      }
    }
  }

  String get _timerLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.kSurface,
        title: Text('화면녹화', style: TextStyle(color: AppConstants.kAccent)),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_recording) ...[
              // 포맷 선택
              Text('출력 포맷', style: TextStyle(color: AppConstants.kAccent, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: _formats.map((f) {
                  final sel = _format == f['id'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _format = f['id'] as String),
                      child: Container(
                        margin: EdgeInsets.only(right: f['id'] == 'shorts' ? 8 : 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sel ? AppConstants.kAccent.withOpacity(0.2) : AppConstants.kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sel ? AppConstants.kAccent : AppConstants.kDim),
                        ),
                        child: Column(children: [
                          Text(f['icon'] as String, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(f['label'] as String,
                              style: TextStyle(color: sel ? AppConstants.kAccent : Colors.white70, fontWeight: FontWeight.bold)),
                          Text(f['desc'] as String,
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 오디오 모드 선택
              Text('오디오 모드', style: TextStyle(color: AppConstants.kAccent, fontSize: 12)),
              const SizedBox(height: 8),
              ..._audioModes.map((m) {
                final mode = m['mode'] as AudioMode;
                final sel = _audioMode == mode;
                return GestureDetector(
                  onTap: () => setState(() => _audioMode = mode),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: sel ? AppConstants.kAccent.withOpacity(0.12) : AppConstants.kSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? AppConstants.kAccent : AppConstants.kDim),
                    ),
                    child: Row(children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: sel ? AppConstants.kAccent : Colors.white38, width: 2),
                          color: sel ? AppConstants.kAccent : Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m['label'] as String,
                            style: TextStyle(
                                color: sel ? AppConstants.kAccent : Colors.white70,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13)),
                        Text(m['desc'] as String,
                            style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
                      ])),
                    ]),
                  ),
                );
              }),

              // DAW 모드 안내
              if (_audioMode == AudioMode.daw)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.kAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.kAccent.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '💡 DAW 모드: FL Studio / BandLab 등 DAW에서 마이크 처리 후 시스템 출력 → Studio가 BGM + 목소리를 함께 캡처\n녹화 전 DAW를 먼저 실행하세요.',
                    style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
                  ),
                ),
            ],

            // 녹화 중 타이머
            if (_recording)
              Expanded(
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 14, height: 14,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(height: 16),
                    Text(_timerLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w200)),
                    const SizedBox(height: 8),
                    Text(
                      '${_format == 'shorts' ? '1080×1920' : '1920×1080'} · ${_audioMode == AudioMode.daw ? 'DAW 믹스' : _audioMode == AudioMode.unprocessed ? '외장 마이크' : '기본 마이크'}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ]),
                ),
              )
            else
              const Spacer(),

            // 녹화 버튼
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: _recording ? Colors.red : AppConstants.kAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _recording ? '⏹ 녹화 중지 → 트리머로' : '⏺ 녹화 시작',
                    style: TextStyle(
                        color: _recording ? Colors.white : Colors.black,
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_recording)
              Text(
                _audioMode == AudioMode.daw
                    ? '화면 + BGM + DAW 목소리를 하나의 MP4로 믹싱합니다.'
                    : '녹화 종료 후 자동으로 트리머로 이동합니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
