import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/constants.dart';

class TrimmerScreen extends StatefulWidget {
  final String videoPath;
  final String format;
  const TrimmerScreen({super.key, required this.videoPath, required this.format});

  @override
  State<TrimmerScreen> createState() => _TrimmerScreenState();
}

class _TrimmerScreenState extends State<TrimmerScreen> {
  VideoPlayerController? _player;
  bool _playerReady = false;
  String _status = '로드 중...';
  late String _fmt;

  static const _fmts = {
    'shorts': {'w': 1080, 'h': 1920, 'label': '📱 Shorts', 'desc': '1080×1920'},
    'long':   {'w': 1920, 'h': 1080, 'label': '🖥️ Long',   'desc': '1920×1080'},
  };

  @override
  void initState() {
    super.initState();
    _fmt = widget.format;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final ctrl = VideoPlayerController.file(File(widget.videoPath));
    await ctrl.initialize();
    ctrl.setLooping(true);
    ctrl.play();
    if (!mounted) { ctrl.dispose(); return; }
    setState(() {
      _player = ctrl;
      _playerReady = true;
      _status = '${ctrl.value.duration.inSeconds}초 · ${_fmts[_fmt]!['desc']}';
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.kSurface,
        title: Text('영상트리머', style: TextStyle(color: AppConstants.kAccent)),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(_status, style: const TextStyle(color: Colors.white38, fontSize: 11)))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _playerReady
                ? AspectRatio(aspectRatio: _player!.value.aspectRatio, child: VideoPlayer(_player!))
                : Container(height: 200, color: AppConstants.kSurface,
                    child: const Center(child: CircularProgressIndicator())),
          ),
          const SizedBox(height: 12),
          Row(children: _fmts.entries.map((e) {
            final sel = _fmt == e.key;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _fmt = e.key),
              child: Container(
                margin: EdgeInsets.only(right: e.key == 'shorts' ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppConstants.kAccent.withValues(alpha: 0.15) : AppConstants.kSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? AppConstants.kAccent : AppConstants.kDim),
                ),
                child: Column(children: [
                  Text(e.value['label']! as String,
                      style: TextStyle(color: sel ? AppConstants.kAccent : Colors.white60, fontSize: 13)),
                  Text(e.value['desc']! as String,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.kDim),
            ),
            child: Column(children: [
              Icon(Icons.cut, color: AppConstants.kAccent.withValues(alpha: 0.4), size: 32),
              const SizedBox(height: 8),
              Text('변환 기능 v2.0 예정',
                  style: TextStyle(color: AppConstants.kAccent, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('네이티브 H.264 인코더 + 크롭 필터\n(현재 버전: 미리보기 전용)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}
