/// App Configuration
/// 환경별 설정값 관리. 하드코딩 제거.
abstract class AppConfig {
  // === MIDI Server ===
  static const String midiServerUrl = String.fromEnvironment(
    'MIDI_SERVER_URL',
    defaultValue: 'https://midi-converter-prod-uc.a.run.app',
  );

  // === Timeouts ===
  static const Duration apiConnectTimeout = Duration(seconds: 30);
  static const Duration apiReceiveTimeout = Duration(minutes: 5);
  static const Duration healthCheckTimeout = Duration(seconds: 5);

  // === Retry Policy ===
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const double retryBackoffMultiplier = 1.5;

  // === Audio Presets (AIVA compliant) ===
  static const List<int> presetDurations = [60, 120, 180]; // seconds
  static const int defaultPreset = 60;
  static const int maxDurationSeconds = 180; // 3분 제한

  // === File Settings ===
  static const List<String> supportedAudioFormats = [
    'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'
  ];
  static const String tempFilePrefix = 'parksy_audio_';
  static const Duration tempFileMaxAge = Duration(hours: 24);
  static const int maxFileSizeMb = 50;

  // === FFmpeg Quality ===
  static const int mp3Quality = 2; // 0-9, lower = better
  static const int wavSampleRate = 44100;

  // === Notifications ===
  static const String recordingNotificationTitle = 'Parksy Audio';
  static const String recordingNotificationMessage = '시스템 오디오 녹음 중...';

  // === Feature Flags ===
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;
  static const bool showDebugBanner = false;
}
