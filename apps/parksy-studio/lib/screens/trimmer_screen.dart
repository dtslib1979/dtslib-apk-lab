import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
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
  bool _processing = false;
  double _progress = 0;
  String _status = '로드 중...';
  String? _outputPath;
  late String _fmt;

  final _cropTopCtrl = TextEditingController(text: '80');
  final _cropBotCtrl = TextEditingController(text: '80');

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
      _status = '로드됨 — ${ctrl.value.duration.inSeconds}초';
    });
  }

  Future<void> _process() async {
    if (_processing) return;
    setState(() { _processing = true; _progress = 0; _status = '변환 중...'; });
    try {
      final extDir = await getExternalStorageDirectory();
      final outDir = Directory('${extDir!.path}/ParksyStudio');
      await outDir.create(recursive: true);
      final ts = DateTime.now().toString().replaceAll(RegExp(r'[: .]'), '-').substring(0, 19);
      final outPath = '${outDir.path}/PS_${_fmt.toUpperCase()}_$ts.mp4';

      final w = _fmts[_fmt]!['w']!;
      final h = _fmts[_fmt]!['h']!;
      final cropTop = int.tryParse(_cropTopCtrl.text) ?? 0;
      final cropBot = int.tryParse(_cropBotCtrl.text) ?? 0;
      final durationMs = (_player?.value.duration.inMilliseconds ?? 1).toDouble();

      final filter = cropTop + cropBot > 0
          ? 'crop=iw:ih-${cropTop + cropBot}:0:$cropTop,scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2'
          : 'scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2';

      FFmpegKitConfig.enableStatisticsCallback((stats) {
        if (!mounted) return;
        setState(() => _progress = (stats.getTime() / durationMs).clamp(0.0, 0.99));
      });

      final session = await FFmpegKit.execute(
        '-i "${widget.videoPath}" -vf "$filter" '
        '-c:v libx264 -preset fast -crf 23 '
        '-c:a aac -b:a 128k -movflags +faststart "$outPath"',
      );

      FFmpegKitConfig.disableStatistics();
      final rc = await session.getReturnCode();
      if (!mounted) return;

      if (ReturnCode.isSuccess(rc)) {
        setState(() { _outputPath = outPath; _status = '✅ ${outPath.split('/').last}'; _progress = 1.0; });
      } else {
        setState(() => _status = '❌ 변환 실패');
      }
    } catch (e) {
      if (mounted) setState(() => _status = '❌ $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _cropTopCtrl.dispose();
    _cropBotCtrl.dispose();
    FFmpegKitConfig.disableStatistics();
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
                  color: sel ? AppConstants.kAccent.withOpacity(0.15) : AppConstants.kSurface,
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
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _numField('위 제거 (px)', _cropTopCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _numField('아래 제거 (px)', _cropBotCtrl)),
          ]),
          const SizedBox(height: 12),
          if (_progress > 0) ...[
            LinearProgressIndicator(
              value: _processing ? null : _progress,
              backgroundColor: AppConstants.kSurface,
              valueColor: AlwaysStoppedAnimation(AppConstants.kAccent),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton(
            onPressed: _processing || !_playerReady ? null : _process,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.kAccent,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppConstants.kSurface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_processing ? '변환 중...' : '⚡ 변환 + 저장',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          if (_outputPath != null) ...[
            const SizedBox(height: 8),
            Text('📁 ${_outputPath!.split('/').last}', textAlign: TextAlign.center,
                style: TextStyle(color: AppConstants.kAccent, fontSize: 12)),
          ],
        ]),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true, fillColor: AppConstants.kSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]);
  }
}
