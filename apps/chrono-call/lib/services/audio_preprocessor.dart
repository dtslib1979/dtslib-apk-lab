import 'dart:io';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';

class AudioPreprocessor {
  /// Preprocess audio for Whisper API:
  /// - Convert to mono (single channel)
  /// - Downsample to 16kHz
  /// - Compress to 64kbps
  /// - Output as m4a (smaller than wav, Whisper accepts it)
  ///
  /// Returns path to preprocessed file, or null on failure.
  static Future<PreprocessResult> preprocess(String inputPath) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${dir.path}/chrono_prep_$timestamp.m4a';

    // Get input file size
    final inputFile = File(inputPath);
    final inputSize = await inputFile.length();
    final inputSizeMB = inputSize / (1024 * 1024);

    // FFmpeg: mono, 16kHz, 64kbps AAC
    final command = '-i "$inputPath" -ac 1 -ar 16000 -b:a 64k -y "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final outputFile = File(outputPath);
      final outputSize = await outputFile.length();
      final outputSizeMB = outputSize / (1024 * 1024);

      return PreprocessResult(
        success: true,
        outputPath: outputPath,
        inputSizeMB: inputSizeMB,
        outputSizeMB: outputSizeMB,
      );
    } else {
      final logs = await session.getLogsAsString();
      return PreprocessResult(
        success: false,
        error: 'FFmpeg failed: $logs',
        inputSizeMB: inputSizeMB,
        outputSizeMB: 0,
      );
    }
  }

  /// Get audio duration in seconds using FFmpeg probe
  static Future<double?> getDuration(String filePath) async {
    final command = '-i "$filePath" -f null -';
    final session = await FFmpegKit.execute(command);
    final logs = await session.getLogsAsString();

    // Parse "Duration: HH:MM:SS.ss" from FFmpeg output
    final regex = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)');
    final match = regex.firstMatch(logs ?? '');
    if (match != null) {
      final h = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final s = int.parse(match.group(3)!);
      final ms = int.parse(match.group(4)!.padRight(2, '0').substring(0, 2));
      return h * 3600.0 + m * 60.0 + s + ms / 100.0;
    }
    return null;
  }

  /// Clean up temporary preprocessed files
  static Future<void> cleanup() async {
    final dir = await getTemporaryDirectory();
    final files = dir.listSync().where(
        (f) => f.path.contains('chrono_prep_') && f.path.endsWith('.m4a'));
    for (final f in files) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
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
