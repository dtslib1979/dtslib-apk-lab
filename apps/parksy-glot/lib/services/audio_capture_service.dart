import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../config/app_config.dart';

/// Service for capturing system audio using Android's AudioPlaybackCapture API
class AudioCaptureService {
  static const _channel = MethodChannel('com.dtslib.parksy_glot/audio');

  final _audioStreamController = StreamController<Uint8List>.broadcast();
  bool _isCapturing = false;

  Stream<Uint8List> get audioStream => _audioStreamController.stream;
  bool get isCapturing => _isCapturing;

  AudioCaptureService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAudioData':
        final data = call.arguments as Uint8List;
        _audioStreamController.add(data);
        break;
      case 'onCaptureError':
        final error = call.arguments as String;
        _audioStreamController.addError(AudioCaptureException(error));
        break;
      case 'onCaptureEnded':
        _isCapturing = false;
        break;
    }
  }

  /// Check if audio capture is available on this device
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request necessary permissions for audio capture
  Future<bool> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Start capturing system audio
  Future<bool> startCapture({
    int sampleRate = 16000,
    int channelCount = 1,
    int bitsPerSample = 16,
  }) async {
    if (_isCapturing) return true;

    try {
      final result = await _channel.invokeMethod<bool>('startCapture', {
        'sampleRate': sampleRate,
        'channelCount': channelCount,
        'bitsPerSample': bitsPerSample,
      });
      _isCapturing = result ?? false;
      return _isCapturing;
    } catch (e) {
      throw AudioCaptureException('Failed to start capture: $e');
    }
  }

  /// Stop capturing audio
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _channel.invokeMethod('stopCapture');
      _isCapturing = false;
    } catch (e) {
      throw AudioCaptureException('Failed to stop capture: $e');
    }
  }

  /// Create media projection for screen/audio capture
  Future<bool> createMediaProjection() async {
    try {
      final result = await _channel.invokeMethod<bool>('createMediaProjection');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    stopCapture();
    _audioStreamController.close();
  }
}

class AudioCaptureException implements Exception {
  final String message;

  AudioCaptureException(this.message);

  @override
  String toString() => 'AudioCaptureException: $message';
}
