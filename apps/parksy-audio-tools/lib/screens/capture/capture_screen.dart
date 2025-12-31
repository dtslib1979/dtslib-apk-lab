import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:system_audio_recorder/system_audio_recorder.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/audio_service.dart';
import '../../services/midi_service.dart';
import '../../widgets/preset_selector.dart';
import '../../widgets/result_card.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool _rec = false;
  bool _proc = false;
  int _preset = 60; // seconds
  int _elapsed = 0;
  Timer? _timer;
  String? _mp3Path;
  String? _midiPath;
  String _status = '녹음 준비';
  String? _recPath;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<bool> _checkPerms() async {
    final mic = await Permission.microphone.request();
    return mic.isGranted;
  }

  Future<void> _startRec() async {
    if (!await _checkPerms()) {
      _showSnack('권한 필요');
      return;
    }

    try {
      // Request MediaProjection permission
      final confirmed = await SystemAudioRecorder.requestRecord(
        titleNotification: 'Parksy Audio',
        messageNotification: '시스템 오디오 녹음 중...',
      );

      if (!confirmed) {
        _showSnack('녹음 권한 거부됨');
        return;
      }

      // Prepare file path
      final dir = await getExternalStorageDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      _recPath = '${dir?.parent.path}/capture_$ts.wav';

      // Delete if exists
      final outFile = File(_recPath!);
      if (outFile.existsSync()) {
        await outFile.delete();
      }

      // Start recording to file
      final started = await SystemAudioRecorder.startRecord(
        toFile: true,
        toStream: false,
        filePath: _recPath,
      );

      if (!started) {
        _showSnack('녹음 시작 실패');
        return;
      }

      setState(() {
        _rec = true;
        _elapsed = 0;
        _status = '녹음 중... 0:00';
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _elapsed++;
          _status = '녹음 중... ${_fmtTime(_elapsed)}';
        });

        if (_elapsed >= _preset) {
          _stopRec();
        }
      });
    } catch (e) {
      _showSnack('녹음 시작 실패: $e');
    }
  }

  Future<void> _stopRec() async {
    _timer?.cancel();
    
    try {
      final path = await SystemAudioRecorder.stopRecord();
      setState(() {
        _rec = false;
        _status = '처리 중...';
        _proc = true;
      });

      // Use returned path or our saved path
      final wavPath = path.isNotEmpty ? path : _recPath;
      if (wavPath != null && wavPath.isNotEmpty) {
        await _process(wavPath);
      } else {
        setState(() {
          _proc = false;
          _status = '녹음 파일 없음';
        });
      }
    } catch (e) {
      setState(() {
        _rec = false;
        _proc = false;
        _status = '녹음 중지 실패: $e';
      });
    }
  }

  Future<void> _process(String wavPath) async {
    try {
      // WAV → MP3
      setState(() => _status = 'MP3 변환 중...');
      final mp3 = await AudioService.toMp3(wavPath);
      
      // MP3 → MIDI
      setState(() => _status = 'MIDI 변환 중...');
      final midi = await MidiService.convert(mp3);

      setState(() {
        _mp3Path = mp3;
        _midiPath = midi;
        _proc = false;
        _status = '완료!';
      });

      // Cleanup WAV
      try {
        await File(wavPath).delete();
      } catch (_) {}
    } catch (e) {
      setState(() {
        _proc = false;
        _status = '변환 실패: $e';
      });
    }
  }

  String _fmtTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _reset() {
    setState(() {
      _mp3Path = null;
      _midiPath = null;
      _status = '녹음 준비';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 화면 녹음 → MIDI'),
        centerTitle: true,
        actions: [
          if (_midiPath != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Preset Selector
            PresetSelector(
              value: _preset,
              enabled: !_rec && !_proc,
              onChanged: (v) => setState(() => _preset = v),
            ),
            const SizedBox(height: 24),

            // Status
            Text(
              _status,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Timer Display
            if (_rec)
              Text(
                _fmtTime(_elapsed),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),

            // Progress
            if (_proc)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),

            const Spacer(),

            // Result
            if (_midiPath != null)
              ResultCard(
                mp3Path: _mp3Path,
                midiPath: _midiPath,
              ),

            const Spacer(),

            // Record Button
            SizedBox(
              width: 200,
              height: 200,
              child: ElevatedButton(
                onPressed: _proc ? null : (_rec ? _stopRec : _startRec),
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: _rec ? Colors.red : Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Icon(
                  _rec ? Icons.stop : Icons.fiber_manual_record,
                  size: 80,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Help text
            Text(
              _rec 
                ? '탭하여 중지 (자동: ${_fmtTime(_preset)})'
                : '탭하여 시스템 오디오 녹음 시작',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
