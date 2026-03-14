import 'package:flutter/services.dart';

class RecordingService {
  static const _channel = MethodChannel('com.parksy.studio/recording');

  static Future<String?> start({String format = 'shorts'}) async {
    try {
      final path = await _channel.invokeMethod<String>('startRecording', {
        'format': format,
      });
      return path;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') return null;
      rethrow;
    }
  }

  static Future<String?> stop() async {
    final path = await _channel.invokeMethod<String>('stopRecording');
    return path;
  }

  static Future<bool> isRecording() async {
    return await _channel.invokeMethod<bool>('isRecording') ?? false;
  }
}
