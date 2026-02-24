import 'package:flutter/services.dart';

class NotesBridge {
  static const _channel = MethodChannel('kr.parksy.liner/notes');

  /// Open image in Samsung Notes for S Pen overdrawing.
  /// Falls back to system share chooser if Samsung Notes not found.
  static Future<bool> openInSamsungNotes(String imagePath) async {
    final result = await _channel.invokeMethod<bool>('openInNotes', {
      'imagePath': imagePath,
    });
    return result ?? false;
  }

  /// Check if Samsung Notes is installed.
  static Future<bool> isSamsungNotesAvailable() async {
    final result =
        await _channel.invokeMethod<bool>('isSamsungNotesAvailable');
    return result ?? false;
  }

  /// Share via system chooser as fallback.
  static Future<void> shareImage(String imagePath) async {
    await _channel.invokeMethod('shareImage', {
      'imagePath': imagePath,
    });
  }
}
