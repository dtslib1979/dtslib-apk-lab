import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';

class LinerProcessor {
  static const _channel = MethodChannel('kr.parksy.liner/engine');

  /// Process image via native Kotlin engine.
  /// Returns map of output file paths.
  static Future<Map<String, String>> process(String inputPath,
      {String? outputDir}) async {
    final result = await _channel.invokeMethod<Map>('processImage', {
      'inputPath': inputPath,
      'outputDir': outputDir,
    });
    if (result == null) throw Exception('Processing returned null');
    return Map<String, String>.from(result);
  }
}
