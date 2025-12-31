import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/duration_utils.dart';
import '../../services/audio_service.dart';
import '../../services/file_manager.dart';

/// Legacy audio trimmer screen
/// Free-form range selection → WAV output
class TrimmerScreen extends StatefulWidget {
  const TrimmerScreen({super.key});

  @override
  State<TrimmerScreen> createState() => _TrimmerScreenState();
}

class _TrimmerScreenState extends State<TrimmerScreen> {
  // Services
  final _audioService = AudioService.instance;
  final _fileManager = FileManager.instance;

  // Source file
  String? _sourcePath;
  String? _sourceName;
  Duration _sourceDuration = Duration.zero;
  Duration _startPosition = Duration.zero;
  Duration _endPosition = Duration.zero;

  // Processing
  bool _isProcessing = false;
  String _statusMessage = '파일 선택';

  // Result
  String? _outputPath;

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

      try {
        await _player.setFilePath(path);
        final duration = _player.duration ?? Duration.zero;

        setState(() {
          _sourcePath = path;
          _sourceName = name;
          _sourceDuration = duration;
          _startPosition = Duration.zero;
          _endPosition = duration;
          _outputPath = null;
          _statusMessage = '구간 설정 후 트림';
        });
      } catch (e) {
        _showMessage('오디오 파일을 읽을 수 없습니다');
      }
    } catch (e) {
      _showMessage('파일 선택 실패: $e');
    }
  }

  Future<void> _trim() async {
    if (_sourcePath == null) return;

    final duration = _endPosition - _startPosition;
    if (duration.inSeconds <= 0) {
      _showMessage('선택 구간이 너무 짧습니다');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '트림 중...';
    });

    final result = await _audioService.trimToWav(
      inputPath: _sourcePath!,
      start: _startPosition,
      duration: duration,
    );

    result.fold(
      onSuccess: (outputPath) {
        setState(() {
          _outputPath = outputPath;
          _isProcessing = false;
          _statusMessage = '완료!';
        });
      },
      onFailure: (error, _) {
        setState(() {
          _isProcessing = false;
          _statusMessage = error;
        });
      },
    );
  }

  Future<void> _share() async {
    if (_outputPath == null) return;

    try {
      await Share.shareXFiles([XFile(_outputPath!)]);
    } catch (e) {
      _showMessage('공유 실패: $e');
    }
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
    // Cleanup previous output
    if (_outputPath != null) {
      _fileManager.delete(_outputPath!);
    }

    setState(() {
      _sourcePath = null;
      _sourceName = null;
      _sourceDuration = Duration.zero;
      _startPosition = Duration.zero;
      _endPosition = Duration.zero;
      _outputPath = null;
      _statusMessage = '파일 선택';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDuration = _endPosition - _startPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오디오 트림'),
        centerTitle: true,
        actions: [
          if (_outputPath != null)
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
                  _sourceName ?? '파일 선택',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),

              // Range Selector
              if (_sourcePath != null) ...[
                Text('전체 길이: ${_sourceDuration.toMmSs()}'),
                const SizedBox(height: 8),

                // Start slider
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text('시작: ${_startPosition.toMmSs()}'),
                    ),
                    Expanded(
                      child: Slider(
                        value: _startPosition.inSeconds.toDouble(),
                        max: _endPosition.inSeconds.toDouble(),
                        onChanged: _isProcessing
                            ? null
                            : (v) => setState(
                                  () => _startPosition = Duration(seconds: v.toInt()),
                                ),
                      ),
                    ),
                  ],
                ),

                // End slider
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text('끝: ${_endPosition.toMmSs()}'),
                    ),
                    Expanded(
                      child: Slider(
                        value: _endPosition.inSeconds.toDouble(),
                        min: _startPosition.inSeconds.toDouble(),
                        max: _sourceDuration.inSeconds.toDouble(),
                        onChanged: _isProcessing
                            ? null
                            : (v) => setState(
                                  () => _endPosition = Duration(seconds: v.toInt()),
                                ),
                      ),
                    ),
                  ],
                ),

                // Selected duration
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '선택: ${selectedDuration.toMmSs()}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

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

              // Trim Button
              if (_sourcePath != null && !_isProcessing && _outputPath == null)
                ElevatedButton.icon(
                  onPressed: _trim,
                  icon: const Icon(Icons.content_cut),
                  label: const Text('트림'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),

              const Spacer(),

              // Result Card
              if (_outputPath != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 48,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 8),
                        const Text('WAV 저장 완료'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share),
                          label: const Text('공유'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
