import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/studio_scenario.dart'; // AudioMode, AudioProfile, StudioScenario
import '../services/recording_service.dart'; // RecordingService
import 'trimmer_screen.dart';

class RecordingScreen extends StatefulWidget {
  /// null → 커스텀 모드 (직접 설정), not null → 시나리오 프리셋
  final StudioScenario? scenario;
  const RecordingScreen({super.key, this.scenario});
  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  late String _format;
  late AudioMode _audioMode;
  late AudioProfile _audioProfile;
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  // 커스텀 모드 전용 설정
  static const _formats = [
    {'id': 'shorts', 'label': 'Shorts', 'desc': '1080×1920  9:16', 'icon': '📱'},
    {'id': 'long',   'label': 'Long',   'desc': '1920×1080  16:9', 'icon': '🖥️'},
  ];

  static const _audioModes = [
    {'mode': AudioMode.mic,          'label': '🎙 기본 마이크',      'desc': 'AGC 적용, 일반 마이크용'},
    {'mode': AudioMode.unprocessed,  'label': '🎤 외장 마이크 원본', 'desc': 'AGC/노이즈게이트 우회\nShure MOTIV USB 권장'},
    {'mode': AudioMode.daw,          'label': '🎛 DAW 믹스 캡처',   'desc': '시스템 오디오 전체 캡처\nBGM + DAW 처리 목소리 믹싱'},
  ];

  static const _profiles = [
    {'p': AudioProfile.lecture, 'label': '🎓 강의',    'desc': 'NS + AGC + AEC — 목소리 선명'},
    {'p': AudioProfile.podcast, 'label': '🎙 팟캐스트', 'desc': 'NS + AGC — 균일한 음량'},
    {'p': AudioProfile.music,   'label': '🎸 음악',    'desc': '이펙트 없음 — 원본 보존'},
    {'p': AudioProfile.raw,     'label': '🔵 원본',    'desc': '이펙트 없음 — DAW/외장 마이크용'},
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.scenario;
    _format       = s?.videoFormat ?? 'shorts';
    _audioMode    = s?.audioSource ?? AudioMode.mic;
    _audioProfile = s?.audioProfile ?? AudioProfile.raw;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) RecordingService.stop();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await RecordingService.stop();
      _timer?.cancel();
      setState(() { _recording = false; });
      if (path != null && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TrimmerScreen(videoPath: path, format: _format),
        ));
      }
    } else {
      final path = await RecordingService.start(
        format: _format,
        audioMode: _audioMode,
        audioProfile: _audioProfile,
      );
      if (path != null) {
        setState(() { _recording = true; _seconds = 0; });
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

  bool get _isScenario => widget.scenario != null && !widget.scenario!.isCustom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.kSurface,
        title: Text(
          _isScenario ? '${widget.scenario!.icon} ${widget.scenario!.name}' : '화면녹화',
          style: TextStyle(color: AppConstants.kAccent),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_recording) ...[
              _isScenario ? _buildScenarioSummary() : _buildCustomSettings(),
            ],

            // 녹화 중 타이머
            if (_recording)
              Expanded(
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 14, height: 14,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(height: 16),
                    Text(_timerLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w200)),
                    const SizedBox(height: 8),
                    Text(
                      '${_format == 'shorts' ? '1080×1920' : '1920×1080'} · ${_audioMode == AudioMode.daw ? 'DAW 믹스' : _audioMode == AudioMode.unprocessed ? '외장 마이크' : '기본 마이크'} · ${_audioProfile.profileName}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ]),
                ),
              )
            else
              const Spacer(),

            // 녹화 버튼
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: _recording ? Colors.red : AppConstants.kAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _recording ? '⏹ 녹화 중지 → 트리머로' : '⏺ 녹화 시작',
                    style: TextStyle(
                        color: _recording ? Colors.white : Colors.black,
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_recording)
              Text(
                _audioMode == AudioMode.daw
                    ? '화면 + BGM + DAW 목소리를 하나의 MP4로 믹싱합니다.'
                    : '녹화 종료 후 자동으로 트리머로 이동합니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── 시나리오 요약 (프리셋 모드) ──────────────────────────────────
  Widget _buildScenarioSummary() {
    final s = widget.scenario!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.kAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppConstants.kAccent.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.desc,
              style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
          const SizedBox(height: 14),
          Row(children: [
            _summaryChip('포맷', s.formatLabel),
            const SizedBox(width: 8),
            _summaryChip('마이크', s.audioSourceLabel),
            const SizedBox(width: 8),
            _summaryChip('이펙트', s.effectsLabel),
          ]),
        ]),
      ),
      if (_audioMode == AudioMode.daw) ...[
        const SizedBox(height: 12),
        _dawNotice(),
      ],
      const SizedBox(height: 20),
    ]);
  }

  Widget _summaryChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppConstants.kSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(color: AppConstants.kAccent, fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  // ── 커스텀 설정 ───────────────────────────────────────────────────
  Widget _buildCustomSettings() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 포맷 선택
      Text('출력 포맷', style: TextStyle(color: AppConstants.kAccent, fontSize: 12)),
      const SizedBox(height: 8),
      Row(
        children: _formats.map((f) {
          final sel = _format == f['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _format = f['id'] as String),
              child: Container(
                margin: EdgeInsets.only(right: f['id'] == 'shorts' ? 8 : 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? AppConstants.kAccent.withOpacity(0.2) : AppConstants.kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? AppConstants.kAccent : AppConstants.kDim),
                ),
                child: Column(children: [
                  Text(f['icon'] as String, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(f['label'] as String,
                      style: TextStyle(
                          color: sel ? AppConstants.kAccent : Colors.white70,
                          fontWeight: FontWeight.bold)),
                  Text(f['desc'] as String,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),

      // 오디오 소스
      Text('오디오 소스', style: TextStyle(color: AppConstants.kAccent, fontSize: 12)),
      const SizedBox(height: 8),
      ..._audioModes.map((m) {
        final mode = m['mode'] as AudioMode;
        final sel = _audioMode == mode;
        return GestureDetector(
          onTap: () => setState(() => _audioMode = mode),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sel ? AppConstants.kAccent.withOpacity(0.12) : AppConstants.kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? AppConstants.kAccent : AppConstants.kDim),
            ),
            child: Row(children: [
              Container(width: 16, height: 16,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: sel ? AppConstants.kAccent : Colors.white38, width: 2),
                      color: sel ? AppConstants.kAccent : Colors.transparent)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['label'] as String,
                    style: TextStyle(
                        color: sel ? AppConstants.kAccent : Colors.white70,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13)),
                Text(m['desc'] as String,
                    style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
              ])),
            ]),
          ),
        );
      }),

      if (_audioMode == AudioMode.daw) ...[
        _dawNotice(),
        const SizedBox(height: 8),
      ],

      // 오디오 프로파일 (DAW 모드 제외)
      if (_audioMode != AudioMode.daw) ...[
        const SizedBox(height: 12),
        Text('오디오 이펙트', style: TextStyle(color: AppConstants.kAccent, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: _profiles.where((p) {
            final ap = p['p'] as AudioProfile;
            // music/raw 둘 다 보여주되 unprocessed면 raw 숨김
            return true;
          }).map((p) {
            final ap = p['p'] as AudioProfile;
            final sel = _audioProfile.profileName == ap.profileName;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _audioProfile = ap),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: sel ? AppConstants.kAccent.withOpacity(0.15) : AppConstants.kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppConstants.kAccent : AppConstants.kDim),
                  ),
                  child: Column(children: [
                    Text(p['label'] as String,
                        style: TextStyle(
                            color: sel ? AppConstants.kAccent : Colors.white60,
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(ap.effectsLabel,
                        style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ],
      const SizedBox(height: 16),
    ]);
  }

  Widget _dawNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.kAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.kAccent.withOpacity(0.3)),
      ),
      child: const Text(
        '💡 DAW 모드: FL Studio / BandLab 등 DAW에서 마이크 처리 후 시스템 출력 → Studio가 BGM + 목소리를 함께 캡처\n녹화 전 DAW를 먼저 실행하세요.',
        style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
      ),
    );
  }
}

// AudioProfile에 effectsLabel 추가 (model에도 있지만 편의상 extension)
extension _AudioProfileExt on AudioProfile {
  String get effectsLabel {
    final parts = <String>[];
    if (noiseSuppressor) parts.add('NS');
    if (autoGainControl) parts.add('AGC');
    if (echoCanceler)    parts.add('AEC');
    return parts.isEmpty ? '원본' : parts.join('+');
  }
}
