// AudioMode는 여기서 정의 — recording_service.dart에서 re-export
enum AudioMode { mic, unprocessed, daw }

// CameraFrame은 camera_overlay.dart에서 정의 — 여기서 re-export
export '../widgets/camera_overlay.dart' show CameraFrame;

// 오디오 이펙트 프로파일
class AudioProfile {
  final bool noiseSuppressor;
  final bool autoGainControl;
  final bool echoCanceler;
  // Equalizer는 AudioTrack(재생) 전용 — 녹화 적용 불가, 향후 PCM 처리로 구현 예정
  // eqLowCut, eqPresenceBoost: TODO
  // noiseGateThreshold: TODO

  const AudioProfile({
    this.noiseSuppressor = false,
    this.autoGainControl = false,
    this.echoCanceler = false,
  });

  // 프리셋
  static const lecture = AudioProfile(noiseSuppressor: true, autoGainControl: true, echoCanceler: true);
  static const podcast = AudioProfile(noiseSuppressor: true, autoGainControl: true);
  static const music   = AudioProfile(); // all off — 원본 보존
  static const raw     = AudioProfile(); // all off

  String get profileName {
    if (noiseSuppressor && autoGainControl && echoCanceler) return 'lecture';
    if (noiseSuppressor && autoGainControl) return 'podcast';
    return 'raw';
  }
}

class StudioScenario {
  final String id;
  final String icon;
  final String name;
  final String desc;
  final String videoFormat;      // 'shorts' | 'long'
  final AudioMode audioSource;   // mic | unprocessed | daw
  final AudioProfile audioProfile;
  final String? bgmChannel;      // 자동 BGM 채널 id
  final String? autoOpenTool;    // 'bgm' | 'interpreter' | null
  final bool interpreterEnabled;
  final String uploadPrivacy;    // 'private' | 'unlisted' | 'public'
  final bool isCustom;
  final bool cameraEnabled;    // 카메라 오버레이 기본값
  final CameraFrame cameraFrame; // 기본 프레임

  const StudioScenario({
    required this.id,
    required this.icon,
    required this.name,
    required this.desc,
    required this.videoFormat,
    required this.audioSource,
    required this.audioProfile,
    this.bgmChannel,
    this.autoOpenTool,
    this.interpreterEnabled = false,
    this.uploadPrivacy = 'private',
    this.isCustom = false,
    this.cameraEnabled = true,
    this.cameraFrame = CameraFrame.plain,
  });

  String get audioSourceLabel => switch (audioSource) {
    AudioMode.mic          => '기본 마이크',
    AudioMode.unprocessed  => '외장 마이크',
    AudioMode.daw          => 'DAW 믹스',
  };

  String get formatLabel => videoFormat == 'shorts' ? '📱 Shorts  9:16' : '🖥️ Long  16:9';

  String get effectsLabel {
    final parts = <String>[];
    if (audioProfile.noiseSuppressor) parts.add('NS');
    if (audioProfile.autoGainControl) parts.add('AGC');
    if (audioProfile.echoCanceler)    parts.add('AEC');
    return parts.isEmpty ? '원본' : parts.join('+');
  }
}

const kScenarios = [
  StudioScenario(
    id: 'shorts_lecture',
    icon: '📱',
    name: 'Shorts 강의',
    desc: '세로 화면 + 강의 보이스\nNS + AGC + AEC 자동 적용',
    videoFormat: 'shorts',
    audioSource: AudioMode.mic,
    audioProfile: AudioProfile.lecture,
    uploadPrivacy: 'private',
    cameraEnabled: true,
    cameraFrame: CameraFrame.plain,
  ),
  StudioScenario(
    id: 'long_lecture',
    icon: '🖥️',
    name: 'Long 강의',
    desc: '가로 화면 + 강의 보이스\nNS + AGC + AEC 자동 적용',
    videoFormat: 'long',
    audioSource: AudioMode.mic,
    audioProfile: AudioProfile.lecture,
    uploadPrivacy: 'private',
    cameraEnabled: true,
    cameraFrame: CameraFrame.iphone,
  ),
  StudioScenario(
    id: 'music_performance',
    icon: '🎸',
    name: '뮤직 퍼포먼스',
    desc: 'Shure MOTIV 원본 + BGM 자동 열기\n이펙트 없음 — 음색 원본 보존',
    videoFormat: 'shorts',
    audioSource: AudioMode.unprocessed,
    audioProfile: AudioProfile.music,
    autoOpenTool: 'bgm',
    uploadPrivacy: 'public',
    cameraEnabled: true,
    cameraFrame: CameraFrame.plain,
  ),
  StudioScenario(
    id: 'reaction_interpret',
    icon: '🌐',
    name: '리액션/통역',
    desc: '동시통역 자동 열기\nNS + AGC 팟캐스트 처리',
    videoFormat: 'shorts',
    audioSource: AudioMode.mic,
    audioProfile: AudioProfile.podcast,
    autoOpenTool: 'interpreter',
    interpreterEnabled: true,
    uploadPrivacy: 'private',
    cameraEnabled: true,
    cameraFrame: CameraFrame.retroTv,
  ),
  StudioScenario(
    id: 'daw_mix',
    icon: '🎛',
    name: 'DAW 믹스',
    desc: 'FL Studio + BGM 시스템 오디오\nBGM + 목소리 한 트랙으로 믹싱',
    videoFormat: 'shorts',
    audioSource: AudioMode.daw,
    audioProfile: AudioProfile.raw,
    autoOpenTool: 'bgm',
    uploadPrivacy: 'private',
    cameraEnabled: false,
  ),
  StudioScenario(
    id: 'custom',
    icon: '⚙️',
    name: '커스텀',
    desc: '포맷 / 마이크 / 이펙트\n직접 선택',
    videoFormat: 'shorts',
    audioSource: AudioMode.mic,
    audioProfile: AudioProfile.raw,
    uploadPrivacy: 'private',
    isCustom: true,
    cameraEnabled: false,
  ),
];
