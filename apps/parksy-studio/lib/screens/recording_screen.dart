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
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _outputPath;

  final _formats = [
    {'id': 'shorts', 'label': 'Shorts', 'desc': '1080×1920  9:16', 'icon': '📱'},
    {'id': 'long',   'label': 'Long',   'desc': '1920×1080  16:9', 'icon': '🖥️'},
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await RecordingService.stop();
      _timer?.cancel();
      setState(() { _recording = false; _outputPath = path; });
      if (path != null && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TrimmerScreen(videoPath: path, format: _format),
        ));
      }
    } else {
      final path = await RecordingService.start(format: _format);
      if (path != null) {
        setState(() { _recording = true; _seconds = 0; _outputPath = null; });
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 포맷 선택
            if (!_recording) ...[
              Text('출력 포맷', style: TextStyle(color: AppConstants.kAccent, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: _formats.map((f) {
                  final sel = _format == f['id'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _format = f['id']!),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: sel ? AppConstants.kAccent.withOpacity(0.2) : AppConstants.kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AppConstants.kAccent : AppConstants.kDim,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(f['icon']!, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 6),
                            Text(f['label']!, style: TextStyle(
                              color: sel ? AppConstants.kAccent : Colors.white70,
                              fontWeight: FontWeight.bold,
                            )),
                            Text(f['desc']!, style: const TextStyle(
                              color: Colors.white38, fontSize: 11,
                            )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],

            // 타이머
            if (_recording) ...[
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_timerLabel, style: const TextStyle(
                      color: Colors.white, fontSize: 56, fontWeight: FontWeight.w200,
                    )),
                    const SizedBox(height: 8),
                    Text(
                      _format == 'shorts' ? '1080×1920  Shorts' : '1920×1080  Long',
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // 녹화 버튼
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: _recording ? Colors.red : AppConstants.kAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _recording ? '⏹ 녹화 중지 → 트리머로' : '⏺ 녹화 시작',
                    style: TextStyle(
                      color: _recording ? Colors.white : Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '녹화 종료 후 자동으로 YouTube 규격으로 변환됩니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
