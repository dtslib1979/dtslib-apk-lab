import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/duration_utils.dart';
import '../../services/audio_service.dart';
import '../../services/file_manager.dart';
import '../../services/midi_service.dart';
import '../../widgets/preset_selector.dart';
import '../../widgets/result_card.dart';

/// File → MIDI converter screen
/// Pick audio file, select start point, convert to MIDI
class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  // Services
  final _audioService = AudioService.instance;
  final _midiService = MidiService.instance;
  final _fileManager = FileManager.instance;

  // Source file
  String? _sourcePath;
  String? _sourceName;
  Duration _sourceDuration = Duration.zero;
  Duration _startPosition = Duration.zero;

  // Processing
  int _presetSeconds = AppConfig.defaultPreset;
  bool _isProcessing = false;
  String _statusMessage = '파일 선택';

  // Results
  String? _mp3Path;
  String? _midiPath;

  final _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConfig.supportedAudioFormats,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.path == null) {
        _showMessage('파일 경로를 가져올 수 없습니다');
        return;
      }

      final path = file.path!;
      final name = file.name;

      // Get duration using just_audio
      try {
        await _player.setFilePath(path);
        final duration = _player.duration ?? Duration.zero;

        setState(() {
          _sourcePath = path;
          _sourceName = name;
          _sourceDuration = duration;
          _startPosition = Duration.zero;
          _mp3Path = null;
          _midiPath = null;
          _statusMessage = '시작점 설정 후 변환';
        });
      } catch (e) {
        _showMessage('오디오 파일을 읽을 수 없습니다');
      }
    } catch (e) {
      _showMessage('파일 선택 실패: $e');
    }
  }

  Future<void> _convert() async {
    if (_sourcePath == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '트림 중...';
    });

    // Step 1: Trim
    final trimResult = await _audioService.trim(
      inputPath: _sourcePath!,
      start: _startPosition,
      duration: Duration(seconds: _presetSeconds),
    );

    if (trimResult.isFailure) {
      setState(() {
        _isProcessing = false;
        _statusMessage = trimResult.errorOrNull ?? '트림 실패';
      });
      return;
    }

    final trimmedPath = trimResult.valueOrNull!;

    // Step 2: MP3
    setState(() => _statusMessage = 'MP3 변환 중...');

    final mp3Result = await _audioService.toMp3(trimmedPath);
    if (mp3Result.isFailure) {
      await _fileManager.delete(trimmedPath);
      setState(() {
        _isProcessing = false;
        _statusMessage = mp3Result.errorOrNull ?? 'MP3 변환 실패';
      });
      return;
    }

    final mp3Path = mp3Result.valueOrNull!;

    // Cleanup trimmed temp
    await _fileManager.delete(trimmedPath);

    // Step 3: MIDI
    setState(() => _statusMessage = 'MIDI 변환 중...');

    final midiResult = await _midiService.convert(mp3Path);
    if (midiResult.isFailure) {
      setState(() {
        _isProcessing = false;
        _statusMessage = midiResult.errorOrNull ?? 'MIDI 변환 실패';
        _mp3Path = mp3Path; // Keep MP3 even if MIDI fails
      });
      return;
    }

    // Success!
    setState(() {
      _mp3Path = mp3Path;
      _midiPath = midiResult.valueOrNull;
      _isProcessing = false;
      _statusMessage = '완료!';
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reset() {
    setState(() {
      _sourcePath = null;
      _sourceName = null;
      _sourceDuration = Duration.zero;
      _startPosition = Duration.zero;
      _mp3Path = null;
      _midiPath = null;
      _statusMessage = '파일 선택';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxStart = (_sourceDuration.inSeconds - _presetSeconds).clamp(0, 9999);

    return Scaffold(
      appBar: AppBar(
        title: const Text('파일 → MIDI'),
        centerTitle: true,
        actions: [
          if (_midiPath != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: '초기화',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File Picker Button
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _sourceName ?? '파일 선택 (${AppConfig.supportedAudioFormats.join("/")})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),

              // Source Info & Start Position
              if (_sourcePath != null) ...[
                Text('전체 길이: ${_sourceDuration.toMmSs()}'),
                const SizedBox(height: 16),

                Text('시작점: ${_startPosition.toMmSs()}'),
                Slider(
                  value: _startPosition.inSeconds.toDouble(),
                  max: maxStart.toDouble(),
                  divisions: maxStart > 0 ? maxStart : null,
                  onChanged: _isProcessing
                      ? null
                      : (v) => setState(
                            () => _startPosition = Duration(seconds: v.toInt()),
                          ),
                ),
                Text(
                  '선택 구간: ${_startPosition.toMmSs()} ~ ${(_startPosition + Duration(seconds: _presetSeconds)).toMmSs()}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],

              // Preset Selector
              PresetSelector(
                value: _presetSeconds,
                enabled: !_isProcessing,
                onChanged: (v) {
                  setState(() {
                    _presetSeconds = v;
                    // Adjust start position if needed
                    final maxStart = (_sourceDuration.inSeconds - v).clamp(0, 9999);
                    if (_startPosition.inSeconds > maxStart) {
                      _startPosition = Duration(seconds: maxStart);
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // Status
              Center(
                child: Text(
                  _statusMessage,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Progress Indicator
              if (_isProcessing)
                const Center(child: CircularProgressIndicator()),

              // Convert Button
              if (_sourcePath != null && !_isProcessing && _midiPath == null)
                ElevatedButton.icon(
                  onPressed: _convert,
                  icon: const Icon(Icons.music_note),
                  label: const Text('MIDI 변환'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),

              const Spacer(),

              // Result Card
              if (_midiPath != null)
                ResultCard(
                  mp3Path: _mp3Path,
                  midiPath: _midiPath,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
