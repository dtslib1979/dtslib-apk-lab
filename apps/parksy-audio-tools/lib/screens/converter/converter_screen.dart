import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_service.dart';
import '../../services/midi_service.dart';
import '../../widgets/preset_selector.dart';
import '../../widgets/result_card.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  String? _srcPath;
  String? _srcName;
  Duration _srcDur = Duration.zero;
  Duration _startPos = Duration.zero;
  int _preset = 60;
  bool _proc = false;
  String? _mp3Path;
  String? _midiPath;
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
      _startPos = Duration.zero;
      _mp3Path = null;
      _midiPath = null;
      _status = '시작점 설정 후 변환';
    });
  }

  Future<void> _convert() async {
    if (_srcPath == null) return;

    setState(() {
      _proc = true;
      _status = '트림 중...';
    });

    try {
      // Trim
      final trimmed = await AudioService.trim(
        _srcPath!,
        _startPos,
        Duration(seconds: _preset),
      );

      // To MP3
      setState(() => _status = 'MP3 변환 중...');
      final mp3 = await AudioService.toMp3(trimmed);

      // To MIDI
      setState(() => _status = 'MIDI 변환 중...');
      final midi = await MidiService.convert(mp3);

      // Cleanup trimmed temp
      await File(trimmed).delete();

      setState(() {
        _mp3Path = mp3;
        _midiPath = midi;
        _proc = false;
        _status = '완료!';
      });
    } catch (e) {
      setState(() {
        _proc = false;
        _status = '변환 실패: $e';
      });
    }
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
        title: const Text('📁 파일 → MIDI'),
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
              label: Text(_srcName ?? '파일 선택 (MP3/WAV/M4A)'),
            ),
            const SizedBox(height: 16),

            // Source Info
            if (_srcPath != null) ...[
              Text('길이: ${_fmtDur(_srcDur)}'),
              const SizedBox(height: 16),

              // Start Position Slider
              Text('시작점: ${_fmtDur(_startPos)}'),
              Slider(
                value: _startPos.inSeconds.toDouble(),
                max: (_srcDur.inSeconds - _preset).clamp(0, 9999).toDouble(),
                onChanged: _proc ? null : (v) {
                  setState(() => _startPos = Duration(seconds: v.toInt()));
                },
              ),
              const SizedBox(height: 16),
            ],

            // Preset Selector
            PresetSelector(
              value: _preset,
              enabled: !_proc,
              onChanged: (v) => setState(() => _preset = v),
            ),
            const SizedBox(height: 24),

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

            // Convert Button
            if (_srcPath != null && !_proc)
              ElevatedButton.icon(
                onPressed: _convert,
                icon: const Icon(Icons.music_note),
                label: const Text('MIDI 변환'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),

            const Spacer(),

            // Result
            if (_midiPath != null)
              ResultCard(
                mp3Path: _mp3Path,
                midiPath: _midiPath,
              ),
          ],
        ),
      ),
    );
  }
}
