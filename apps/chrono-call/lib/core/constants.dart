class AppConstants {
  static const String appName = 'Parksy ChronoCall';
  static const String version = '1.0.0';
  static const int versionCode = 1;

  // Whisper API
  static const String whisperEndpoint = 'https://api.openai.com/v1/audio/transcriptions';
  static const String whisperModel = 'whisper-1';
  static const int maxFileSizeMB = 25; // Whisper API limit

  // FFmpeg preprocess: stereo → mono, 44.1kHz → 16kHz, compress
  static const String ffmpegPreprocessArgs = '-ac 1 -ar 16000 -b:a 64k';

  // Samsung call recording known paths
  static const List<String> samsungRecordingPaths = [
    '/storage/emulated/0/Recordings/Call',
    '/storage/emulated/0/DCIM/.Recordings/Call',
    '/storage/emulated/0/Call',
    '/storage/emulated/0/Record/Call',
  ];

  // Export
  static const String exportDir = 'Download/ChronoCall';

  // Prefs keys
  static const String prefApiKey = 'openai_api_key';
  static const String prefAutoShare = 'auto_share_capture';
  static const String prefHistory = 'transcript_history';
}
