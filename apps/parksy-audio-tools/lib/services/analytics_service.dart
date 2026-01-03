import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Analytics and crash reporting service
/// Tracks user actions and reports errors
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;
  AnalyticsService._();

  late final FirebaseAnalytics _analytics;
  late final FirebaseCrashlytics _crashlytics;
  bool _initialized = false;

  /// Initialize Firebase services
  Future<void> init() async {
    if (_initialized) return;
    
    _analytics = FirebaseAnalytics.instance;
    _crashlytics = FirebaseCrashlytics.instance;
    _initialized = true;
  }

  // === SCREEN TRACKING ===

  Future<void> logScreenView(String name) async {
    if (!_initialized) return;
    await _analytics.logScreenView(screenName: name);
  }

  // === CONVERSION EVENTS ===

  Future<void> logRecordingStart(int presetSeconds) async {
    if (!_initialized) return;
    await _analytics.logEvent(
      name: 'recording_start',
      parameters: {'preset_seconds': presetSeconds},
    );
  }

  Future<void> logRecordingComplete(int durationSeconds) async {
    if (!_initialized) return;
    await _analytics.logEvent(
      name: 'recording_complete',
      parameters: {'duration_seconds': durationSeconds},
    );
  }

  Future<void> logMidiConversionStart(String source) async {
    if (!_initialized) return;
    await _analytics.logEvent(
      name: 'midi_conversion_start',
      parameters: {'source': source}, // 'capture' or 'file'
    );
  }

  Future<void> logMidiConversionSuccess(int processingMs) async {
    if (!_initialized) return;
    await _analytics.logEvent(
      name: 'midi_conversion_success',
      parameters: {'processing_ms': processingMs},
    );
  }

  Future<void> logMidiConversionError(String errorCode) async {
    if (!_initialized) return;
    await _analytics.logEvent(
      name: 'midi_conversion_error',
      parameters: {'error_code': errorCode},
    );
  }

  Future<void> logFileShare(String fileType) async {
    if (!_initialized) return;
    await _analytics.logEvent(
      name: 'file_share',
      parameters: {'file_type': fileType}, // 'mp3' or 'midi'
    );
  }

  // === ERROR REPORTING ===

  Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_initialized) return;
    await _crashlytics.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  void log(String message) {
    if (!_initialized) return;
    _crashlytics.log(message);
  }

  Future<void> setUserProperty(String name, String value) async {
    if (!_initialized) return;
    await _analytics.setUserProperty(name: name, value: value);
  }
}
