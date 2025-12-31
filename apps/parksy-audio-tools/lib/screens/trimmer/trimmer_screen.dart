import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/audio_service.dart';

class TrimmerScreen extends StatefulWidget {
  const TrimmerScreen({super.key});

  @override
  State<TrimmerScreen> createState() => _TrimmerScreenState();
}

class _TrimmerScreenState extends State<TrimmerScreen> {
  String? _srcPath;
  String? _srcName;
  Duration _srcDur = Duration.zero;
  Duration _start = Duration.zero;
  Duration _end = Duration.zero;
  bool _proc = false;
  String? _outPath;
  String _status = '파일 선택';

  final _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
    );

    if (result == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;

    await _player.setFilePath(path);
    final dur = _player.duration ?? Duration.zero;

    setState(() {
      _srcPath = path;
      _srcName = name;
      _srcDur = dur;
      _start = Duration.zero;
      _end = dur;
      _outPath = null;
      _status = '구간 설정 후 트림';
    });
  }

  Future<void> _trim() async {
    if (_srcPath == null) return;

    setState(() {
      _proc = true;
      _status = '트림 중...';
    });

    try {
      final duration = _end - _start;
      final out = await AudioService.trimToWav(
        _srcPath!,
        _start,
        duration,
      );

      setState(() {
        _outPath = out;
        _proc = false;
        _status = '완료!';
      });
    } catch (e) {
      setState(() {
        _proc = false;
        _status = '트림 실패: $e';
      });
    }
  }

  Future<void> _share() async {
    if (_outPath == null) return;
    await Share.shareXFiles([XFile(_outPath!)]);
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ 오디오 트림'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File Picker
            ElevatedButton.icon(
              onPressed: _proc ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: Text(_srcName ?? '파일 선택'),
            ),
            const SizedBox(height: 16),

            // Range Selector
            if (_srcPath != null) ...[
              Text('전체 길이: ${_fmtDur(_srcDur)}'),
              const SizedBox(height: 8),

              Text('시작: ${_fmtDur(_start)}'),
              Slider(
                value: _start.inSeconds.toDouble(),
                max: _end.inSeconds.toDouble(),
                onChanged: _proc ? null : (v) {
                  setState(() => _start = Duration(seconds: v.toInt()));
                },
              ),

              Text('끝: ${_fmtDur(_end)}'),
              Slider(
                value: _end.inSeconds.toDouble(),
                min: _start.inSeconds.toDouble(),
                max: _srcDur.inSeconds.toDouble(),
                onChanged: _proc ? null : (v) {
                  setState(() => _end = Duration(seconds: v.toInt()));
                },
              ),

              Text('선택 구간: ${_fmtDur(_end - _start)}'),
              const SizedBox(height: 16),
            ],

            // Status
            Center(
              child: Text(
                _status,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),

            // Progress
            if (_proc)
              const Center(child: CircularProgressIndicator()),

            // Trim Button
            if (_srcPath != null && !_proc)
              ElevatedButton.icon(
                onPressed: _trim,
                icon: const Icon(Icons.content_cut),
                label: const Text('트림'),
              ),

            const Spacer(),

            // Result
            if (_outPath != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, size: 48, color: Colors.green),
                      const SizedBox(height: 8),
                      const Text('WAV 저장 완료'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share),
                        label: const Text('공유'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
