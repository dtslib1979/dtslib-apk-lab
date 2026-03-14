import 'package:flutter/services.dart';

enum AudioMode { mic, unprocessed, daw }

class RecordingService {
  static const _channel = MethodChannel('com.parksy.studio/recording');

  static Future<String?> start({
    String format = 'shorts',
    AudioMode audioMode = AudioMode.mic,
  }) async {
    try {
      final path = await _channel.invokeMethod<String>('startRecording', {
        'format': format,
        'audioMode': audioMode.name,
      });
      return path;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') return null;
      rethrow;
    }
  }

  static Future<String?> stop() async {
    return await _channel.invokeMethod<String>('stopRecording');
  }

  static Future<bool> isRecording() async {
    return await _channel.invokeMethod<bool>('isRecording') ?? false;
  }
}
