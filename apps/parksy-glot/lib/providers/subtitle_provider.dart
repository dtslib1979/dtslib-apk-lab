import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/subtitle.dart';
import '../models/language.dart';
import '../services/audio_capture_service.dart';
import '../services/whisper_service.dart';
import '../services/translation_service.dart';
import '../services/overlay_service.dart';
import '../config/app_config.dart';

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

  StreamSubscription? _audioSubscription;
  StreamSubscription? _transcriptionSubscription;

  // Getters
  CaptureState get state => _state;
  Subtitle get currentSubtitle => _currentSubtitle;
  List<Subtitle> get history => List.unmodifiable(_history);
  Language get sourceLanguage => _sourceLanguage;
  bool get showOriginal => _showOriginal;
  String? get errorMessage => _errorMessage;

  bool get isCapturing => _state == CaptureState.capturing;
  bool get isPreparing => _state == CaptureState.preparing;
  bool get isIdle => _state == CaptureState.idle;
  bool get hasError => _state == CaptureState.error;

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
      _errorMessage = e.toString();
      _setState(CaptureState.error);
      return false;
    }
  }

  /// Stop capture
  Future<void> stopCapture() async {
    _audioSubscription?.cancel();
    _transcriptionSubscription?.cancel();

    await _audioCaptureService.stopCapture();
    await OverlayService.hideOverlay();
    await OverlayService.stopService();

    _setState(CaptureState.idle);
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
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  /// Process transcription result
  Future<void> _processTranscription(TranscriptionResult transcription) async {
    if (transcription.text.trim().isEmpty) return;

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

      // Keep history limited
      if (_history.length > 100) {
        _history = _history.sublist(0, 100);
      }

      // Update overlay
      await OverlayService.updateSubtitle(
        korean: subtitle.korean,
        english: subtitle.english,
        original: subtitle.original,
        showOriginal: _showOriginal,
      );

      notifyListeners();
    } catch (e) {
      print('Translation error: $e');
    }
  }

  /// Clear subtitle history
  void clearHistory() {
    _history.clear();
    _currentSubtitle = Subtitle.empty();
    notifyListeners();
  }

  void _setState(CaptureState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    stopCapture();
    _audioCaptureService.dispose();
    super.dispose();
  }
}
