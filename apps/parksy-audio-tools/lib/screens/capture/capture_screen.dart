import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_audio_recorder/system_audio_recorder.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/duration_utils.dart';
import '../../services/analytics_service.dart';
import '../../services/audio_service.dart';
import '../../services/file_manager.dart';
import '../../services/midi_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/preset_selector.dart';
import '../../widgets/result_card.dart';

/// Screen audio capture → MIDI conversion
/// Uses MediaProjection for system audio recording
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with OfflineAwareMixin {
  // Services
  final _audioService = AudioService.instance;
  final _midiService = MidiService.instance;
  final _fileManager = FileManager.instance;
  final _permissionService = PermissionService.instance;
  final _analytics = AnalyticsService.instance;

  // State
  bool _isRecording = false;
  bool _isProcessing = false;
  int _presetSeconds = AppConfig.defaultPreset;
  int _elapsedSeconds = 0;
  Timer? _timer;

  // Results
  String? _mp3Path;
  String? _midiPath;
  String _statusMessage = '녹음 준비';
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _analytics.logScreenView('capture');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Start recording with permission check
  Future<void> _startRecording() async {
    // Offline check before starting
    if (!checkOnlineStatus()) {
      _showMessage('MIDI 변환에 인터넷 연결이 필요합니다');
      return;
    }

    // Check permissions
    final permResult = await _permissionService.requestCapturePermissions();
    if (!mounted) return;

    final hasPermission = await _permissionService.handlePermissionResult(
      context,
      permResult,
    );
    if (!hasPermission) return;

    try {
      // Request MediaProjection permission
      final confirmed = await SystemAudioRecorder.requestRecord(
        titleNotification: AppConfig.recordingNotificationTitle,
        messageNotification: AppConfig.recordingNotificationMessage,
      );

      if (!confirmed) {
        _showMessage('녹음 권한이 거부되었습니다');
        return;
      }

      // Get recording path
      final pathResult = await _fileManager.getRecordingPath();
      if (pathResult.isFailure) {
        _showMessage(pathResult.errorOrNull ?? '경로 생성 실패');
        return;
      }
      _recordingPath = pathResult.valueOrNull;

      // Delete existing file if any
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Start recording
      final started = await SystemAudioRecorder.startRecord(
        toFile: true,
        toStream: false,
        filePath: _recordingPath,
      );

      if (!started) {
        _showMessage('녹음 시작에 실패했습니다');
        return;
      }

      _analytics.logRecordingStart(_presetSeconds);

      setState(() {
        _isRecording = true;
        _elapsedSeconds = 0;
        _statusMessage = '녹음 중... 0:00';
      });

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
    } catch (e) {
      _showMessage('녹음 시작 실패: $e');
    }
  }

  void _onTimerTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    setState(() {
      _elapsedSeconds++;
      _statusMessage = '녹음 중... ${_elapsedSeconds.seconds.toMmSs()}';
    });

    // Auto-stop at preset duration
    if (_elapsedSeconds >= _presetSeconds) {
      _stopRecording();
    }
  }

  /// Stop recording and process
  Future<void> _stopRecording() async {
    _timer?.cancel();

    try {
      final returnedPath = await SystemAudioRecorder.stopRecord();

      _analytics.logRecordingComplete(_elapsedSeconds);

      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusMessage = '처리 중...';
      });

      // Use returned path or our saved path
      final wavPath = returnedPath.isNotEmpty ? returnedPath : _recordingPath;

      if (wavPath == null || wavPath.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '녹음 파일을 찾을 수 없습니다';
        });
        return;
      }

      await _processRecording(wavPath);
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusMessage = '녹음 중지 실패: $e';
      });
    }
  }

  /// Process recording: WAV → MP3 → MIDI
  Future<void> _processRecording(String wavPath) async {
    final startTime = DateTime.now();
    _analytics.logMidiConversionStart('capture');

    // Step 1: WAV → MP3
    setState(() => _statusMessage = 'MP3 변환 중...');

    final mp3Result = await _audioService.toMp3(wavPath);
    if (mp3Result.isFailure) {
      _analytics.logMidiConversionError('mp3_failed');
      setState(() {
        _isProcessing = false;
        _statusMessage = mp3Result.errorOrNull ?? 'MP3 변환 실패';
      });
      return;
    }

    final mp3Path = mp3Result.valueOrNull!;

    // Step 2: MP3 → MIDI
    setState(() => _statusMessage = 'MIDI 변환 중...');

    final midiResult = await _midiService.convert(mp3Path);
    if (midiResult.isFailure) {
      _analytics.logMidiConversionError('midi_failed');
      setState(() {
        _isProcessing = false;
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
      _statusMessage = '완료!';
    });

    // Cleanup WAV
    await _fileManager.delete(wavPath);
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
      _mp3Path = null;
      _midiPath = null;
      _statusMessage = '녹음 준비';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('화면 녹음 → MIDI'),
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
            children: [
              // Preset Selector
              PresetSelector(
                value: _presetSeconds,
                enabled: !_isRecording && !_isProcessing,
                onChanged: (v) => setState(() => _presetSeconds = v),
              ),
              const SizedBox(height: 24),

              // Status
              Text(
                _statusMessage,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Timer Display (recording)
              if (_isRecording)
                Text(
                  _elapsedSeconds.seconds.toMmSs(),
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),

              // Progress Indicator (processing)
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),

              const Spacer(),

              // Result Card
              if (_midiPath != null)
                ResultCard(
                  mp3Path: _mp3Path,
                  midiPath: _midiPath,
                ),

              const Spacer(),

              // Record Button
              _buildRecordButton(),
              const SizedBox(height: 16),

              // Help Text
              Text(
                _isRecording
                    ? '탭하여 중지 (자동: ${_presetSeconds.seconds.toMmSs()})'
                    : '탭하여 시스템 오디오 녹음 시작',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return SizedBox(
      width: 200,
      height: 200,
      child: ElevatedButton(
        onPressed: _isProcessing
            ? null
            : (_isRecording ? _stopRecording : _startRecording),
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade700,
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.fiber_manual_record,
          size: 80,
        ),
      ),
    );
  }
}
