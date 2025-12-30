import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/subtitle.dart';
import '../models/language.dart';
import '../services/audio_capture_service.dart';
import '../services/whisper_service.dart';
import '../services/translation_service.dart';
import '../services/overlay_service.dart';
import '../services/storage_service.dart';
import '../config/app_config.dart';
import '../utils/error_handler.dart';

enum CaptureState { idle, preparing, capturing, paused, error }

class SubtitleProvider extends ChangeNotifier {
  final AudioCaptureService _audioCaptureService = AudioCaptureService();
  final WhisperService _whisperService = WhisperService();
  final TranslationService _translationService = TranslationService();

  CaptureState _state = CaptureState.idle;
  Subtitle _currentSubtitle = Subtitle.empty();
  List<Subtitle> _history = [];
  Language _sourceLanguage = Language.auto;
  bool _showOriginal = false;
  String? _errorMessage;

  // Processing states
  bool _isProcessing = false;
  int _processedCount = 0;
  DateTime? _lastProcessedTime;

  // Session management
  String? _currentSessionId;
  bool _autoSave = true;

  StreamSubscription? _audioSubscription;
  StreamSubscription? _transcriptionSubscription;

  // Getters
  CaptureState get state => _state;
  Subtitle get currentSubtitle => _currentSubtitle;
  List<Subtitle> get history => List.unmodifiable(_history);
  Language get sourceLanguage => _sourceLanguage;
  bool get showOriginal => _showOriginal;
  String? get errorMessage => _errorMessage;
  String? get currentSessionId => _currentSessionId;
  bool get hasUnsavedData => _history.isNotEmpty;

  bool get isCapturing => _state == CaptureState.capturing;
  bool get isPreparing => _state == CaptureState.preparing;
  bool get isIdle => _state == CaptureState.idle;
  bool get hasError => _state == CaptureState.error;
  bool get isProcessing => _isProcessing;
  int get processedCount => _processedCount;
  DateTime? get lastProcessedTime => _lastProcessedTime;

  /// 마지막 처리 이후 경과 시간 (초)
  int get secondsSinceLastProcess {
    if (_lastProcessedTime == null) return 0;
    return DateTime.now().difference(_lastProcessedTime!).inSeconds;
  }

  SubtitleProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    _sourceLanguage = Language.fromCode(AppConfig.sourceLanguage);
    _showOriginal = AppConfig.showOriginal;
  }

  /// Set source language
  void setSourceLanguage(Language language) {
    _sourceLanguage = language;
    AppConfig.sourceLanguage = language.code;
    notifyListeners();
  }

  /// Toggle original text visibility
  void toggleOriginal() {
    _showOriginal = !_showOriginal;
    AppConfig.showOriginal = _showOriginal;
    OverlayService.toggleOriginal(_showOriginal);
    notifyListeners();
  }

  /// Start real-time subtitle capture
  Future<bool> startCapture() async {
    if (_state == CaptureState.capturing) return true;

    _setState(CaptureState.preparing);
    _errorMessage = null;

    // Create new session
    _currentSessionId = StorageService.createSessionId();
    _history.clear();

    try {
      // Check permissions
      if (!await _audioCaptureService.isAvailable()) {
        throw Exception('Audio capture not available on this device');
      }

      final hasPermission = await _audioCaptureService.requestPermissions();
      if (!hasPermission) {
        throw Exception('Audio capture permission denied');
      }

      // Create media projection
      final projectionCreated = await _audioCaptureService.createMediaProjection();
      if (!projectionCreated) {
        throw Exception('Failed to create media projection');
      }

      // Start capture
      final started = await _audioCaptureService.startCapture();
      if (!started) {
        throw Exception('Failed to start audio capture');
      }

      // Start overlay
      await OverlayService.startService();
      await OverlayService.showOverlay();

      // Listen to audio stream
      _startTranscriptionPipeline();

      _setState(CaptureState.capturing);
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      _errorMessage = ErrorHandler.getUserMessage(e);
      _setState(CaptureState.error);
      return false;
    }
  }

  /// Stop capture and optionally save
  Future<String?> stopCapture({bool save = true}) async {
    _audioSubscription?.cancel();
    _transcriptionSubscription?.cancel();

    await _audioCaptureService.stopCapture();
    await OverlayService.hideOverlay();
    await OverlayService.stopService();

    String? savedPath;

    // Auto-save if enabled and we have data
    if (save && _autoSave && _history.isNotEmpty && _currentSessionId != null) {
      savedPath = await saveCurrentSession();
    }

    _setState(CaptureState.idle);
    return savedPath;
  }

  /// Save current session
  Future<String?> saveCurrentSession({String? title}) async {
    if (_history.isEmpty) return null;

    final sessionId = _currentSessionId ?? StorageService.createSessionId();

    try {
      final path = await StorageService.saveSession(
        sessionId: sessionId,
        subtitles: _history.reversed.toList(), // Chronological order
        title: title,
      );
      return path;
    } catch (e) {
      print('Save error: $e');
      return null;
    }
  }

  /// Export current session
  Future<String?> exportSession(ExportFormat format, {String? filename}) async {
    if (_history.isEmpty) return null;

    String content;
    switch (format) {
      case ExportFormat.txt:
        content = await StorageService.exportAsText(_history.reversed.toList());
        break;
      case ExportFormat.srt:
        content = await StorageService.exportAsSrt(_history.reversed.toList());
        break;
      case ExportFormat.json:
        content = await StorageService.exportAsJson(_history.reversed.toList());
        break;
    }

    final name = filename ?? _currentSessionId ?? StorageService.createSessionId();
    return StorageService.saveExport(
      content: content,
      filename: name,
      format: format,
    );
  }

  /// Start the transcription and translation pipeline
  void _startTranscriptionPipeline() {
    final transcriptionStream = _whisperService.transcribeStream(
      _audioCaptureService.audioStream,
      language: _sourceLanguage == Language.auto ? null : _sourceLanguage.code,
    );

    _transcriptionSubscription = transcriptionStream.listen(
      (transcription) async {
        await _processTranscription(transcription);
      },
      onError: (error) {
        ErrorHandler.log(error);
        _errorMessage = ErrorHandler.getUserMessage(error);
        notifyListeners();
      },
    );
  }

  /// Process transcription result
  Future<void> _processTranscription(TranscriptionResult transcription) async {
    if (transcription.text.trim().isEmpty) return;

    _isProcessing = true;
    notifyListeners();

    try {
      // Detect language from Whisper response
      final detectedLang = Language.fromCode(transcription.language);

      // Translate to Korean and English
      final translation = await _translationService.translate(
        transcription.text,
        sourceLanguage: detectedLang,
      );

      // Create subtitle
      final subtitle = Subtitle(
        original: transcription.text,
        detectedLanguage: detectedLang,
        korean: translation.korean,
        english: translation.english,
      );

      _currentSubtitle = subtitle;
      _history.insert(0, subtitle);
      _processedCount++;
      _lastProcessedTime = DateTime.now();

      // Keep history limited
      if (_history.length > 500) {
        _history = _history.sublist(0, 500);
      }

      // Update overlay
      await OverlayService.updateSubtitle(
        korean: subtitle.korean,
        english: subtitle.english,
        original: subtitle.original,
        showOriginal: _showOriginal,
      );
    } catch (e) {
      ErrorHandler.log(e);
      // Don't show translation errors to user, just log them
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Clear subtitle history
  void clearHistory() {
    _history.clear();
    _currentSubtitle = Subtitle.empty();
    _currentSessionId = null;
    notifyListeners();
  }

  void _setState(CaptureState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    stopCapture(save: true);
    _audioCaptureService.dispose();
    super.dispose();
  }
}
