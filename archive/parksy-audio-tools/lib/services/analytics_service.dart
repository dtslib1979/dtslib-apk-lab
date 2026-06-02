import 'dart:async';
import 'package:flutter/foundation.dart';

/// Analytics stub service (Firebase disabled)
/// Enable Firebase in pubspec.yaml when google-services.json is added
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;
  AnalyticsService._();

  bool _initialized = false;

  /// Initialize analytics (stub - logs to console in debug)
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _log('Analytics initialized (stub mode)');
  }

  // === SCREEN TRACKING ===

  Future<void> logScreenView(String name) async {
    _log('Screen: $name');
  }

  // === CONVERSION EVENTS ===

  Future<void> logRecordingStart(int presetSeconds) async {
    _log('Event: recording_start (preset: ${presetSeconds}s)');
  }

  Future<void> logRecordingComplete(int durationSeconds) async {
    _log('Event: recording_complete (duration: ${durationSeconds}s)');
  }

  Future<void> logMidiConversionStart(String source) async {
    _log('Event: midi_conversion_start (source: $source)');
  }

  Future<void> logMidiConversionSuccess(int processingMs) async {
    _log('Event: midi_conversion_success (time: ${processingMs}ms)');
  }

  Future<void> logMidiConversionError(String errorCode) async {
    _log('Event: midi_conversion_error (code: $errorCode)');
  }

  Future<void> logFileShare(String fileType) async {
    _log('Event: file_share (type: $fileType)');
  }

  // === ERROR REPORTING ===

  Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    _log('Error: $error${reason != null ? ' ($reason)' : ''}');
    if (kDebugMode && stack != null) {
      debugPrintStack(stackTrace: stack, maxFrames: 5);
    }
  }

  void log(String message) {
    _log('Log: $message');
  }

  Future<void> setUserProperty(String name, String value) async {
    _log('Property: $name = $value');
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[Analytics] $msg');
  }
}
