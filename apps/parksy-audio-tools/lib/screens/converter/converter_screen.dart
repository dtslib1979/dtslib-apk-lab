import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/duration_utils.dart';
import '../../services/analytics_service.dart';
import '../../services/audio_service.dart';
import '../../services/file_manager.dart';
import '../../services/midi_service.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/preset_selector.dart';
import '../../widgets/result_card.dart';

/// File → MIDI converter screen
/// Pick audio file, select start point, convert to MIDI
class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen>
    with OfflineAwareMixin {
  // Services
  final _audioService = AudioService.instance;
  final _midiService = MidiService.instance;
  final _fileManager = FileManager.instance;
  final _analytics = AnalyticsService.instance;

  // Source file
  String? _sourcePath;
  String? _sourceName;
  Duration _sourceDuration = Duration.zero;
  Duration _startPosition = Duration.zero;

  // Processing
  int _presetSeconds = AppConfig.defaultPreset;
  bool _isProcessing = false;
  String _statusMessage = '파일 선택';
  int _currentStep = 0; // 0: idle, 1: trim, 2: mp3, 3: midi

  // Results
  String? _mp3Path;
  String? _midiPath;

  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _analytics.logScreenView('converter');
  }

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
          _currentStep = 0;
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

    // Offline check
    if (!checkOnlineStatus()) return;

    _analytics.logMidiConversionStart('file');

    setState(() {
      _isProcessing = true;
      _currentStep = 1;
      _statusMessage = '트림 중... (1/3)';
    });

    final startTime = DateTime.now();

    // Step 1: Trim
    final trimResult = await _audioService.trim(
      inputPath: _sourcePath!,
      start: _startPosition,
      duration: Duration(seconds: _presetSeconds),
    );

    if (trimResult.isFailure) {
      _analytics.logMidiConversionError('trim_failed');
      setState(() {
        _isProcessing = false;
        _currentStep = 0;
        _statusMessage = trimResult.errorOrNull ?? '트림 실패';
      });
      return;
    }

    final trimmedPath = trimResult.valueOrNull!;

    // Step 2: MP3
    setState(() {
      _currentStep = 2;
      _statusMessage = 'MP3 변환 중... (2/3)';
    });

    final mp3Result = await _audioService.toMp3(trimmedPath);
    if (mp3Result.isFailure) {
      await _fileManager.delete(trimmedPath);
      _analytics.logMidiConversionError('mp3_failed');
      setState(() {
        _isProcessing = false;
        _currentStep = 0;
        _statusMessage = mp3Result.errorOrNull ?? 'MP3 변환 실패';
      });
      return;
    }

    final mp3Path = mp3Result.valueOrNull!;

    // Cleanup trimmed temp
    await _fileManager.delete(trimmedPath);

    // Step 3: MIDI
    setState(() {
      _currentStep = 3;
      _statusMessage = 'MIDI 변환 중... (3/3)';
    });

    final midiResult = await _midiService.convert(mp3Path);
    if (midiResult.isFailure) {
      _analytics.logMidiConversionError('midi_failed');
      setState(() {
        _isProcessing = false;
        _currentStep = 0;
        _statusMessage = midiResult.errorOrNull ?? 'MIDI 변환 실패';
        _mp3Path = mp3Path; // Keep MP3 even if MIDI fails
      });
      return;
    }

    // Success!
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    _analytics.logMidiConversionSuccess(elapsed);

    setState(() {
      _mp3Path = mp3Path;
      _midiPath = midiResult.valueOrNull;
      _isProcessing = false;
      _currentStep = 0;
      _statusMessage = '완료! (${(elapsed / 1000).toStringAsFixed(1)}초)';
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
      _currentStep = 0;
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

              // Status with step indicator
              Center(
                child: Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (_isProcessing) ...[
                      const SizedBox(height: 12),
                      _buildStepIndicator(),
                    ],
                  ],
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

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(1, '트림'),
        _stepLine(1),
        _stepDot(2, 'MP3'),
        _stepLine(2),
        _stepDot(3, 'MIDI'),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive 
              ? theme.colorScheme.primary 
              : theme.colorScheme.surfaceContainerHighest,
            border: isCurrent 
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
          ),
          child: Center(
            child: isActive
              ? Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary)
              : Text('$step', style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    final theme = Theme.of(context);

    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive 
        ? theme.colorScheme.primary 
        : theme.colorScheme.surfaceContainerHighest,
    );
  }
}
