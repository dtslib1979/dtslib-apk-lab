import 'dart:io';
import 'package:just_audio/just_audio.dart';

class AudioPreprocessor {
  /// Get audio duration using just_audio
  static Future<double?> getDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(filePath);
      if (duration != null) {
        return duration.inMilliseconds / 1000.0;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }

  /// Pass-through: no FFmpeg preprocessing, just check file size.
  /// Whisper API accepts m4a/mp3/wav directly.
  /// Phase 2: re-add FFmpeg compression when package is available.
  static Future<PreprocessResult> preprocess(String inputPath) async {
    final file = File(inputPath);
    final size = await file.length();
    final sizeMB = size / (1024 * 1024);

    return PreprocessResult(
      success: true,
      outputPath: inputPath,
      inputSizeMB: sizeMB,
      outputSizeMB: sizeMB,
    );
  }

  /// No-op cleanup (no temp files without FFmpeg)
  static Future<void> cleanup() async {}
}

class PreprocessResult {
  final bool success;
  final String? outputPath;
  final String? error;
  final double inputSizeMB;
  final double outputSizeMB;

  PreprocessResult({
    required this.success,
    this.outputPath,
    this.error,
    required this.inputSizeMB,
    required this.outputSizeMB,
  });

  String get compressionRatio {
    if (inputSizeMB == 0) return '-';
    final ratio = (1 - outputSizeMB / inputSizeMB) * 100;
    return '${ratio.toStringAsFixed(0)}%';
  }
}
