import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';

class PcmConverter {
  static const int sampleRate = 44100;
  static const int channels = 1; // mono
  static const int bitDepth = 16;

  /// Convert audio file to mono PCM (44.1kHz, 16-bit, little-endian)
  /// Returns raw PCM bytes or null on failure
  static Future<Int16List?> convertToMonoPcm(String inputPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final outputPath = '${dir.path}/temp_mono.pcm';

    // FFmpeg command: convert to mono 44.1kHz 16-bit signed little-endian PCM
    final cmd = '-y -i "$inputPath" '
        '-ac $channels '
        '-ar $sampleRate '
        '-f s16le '
        '-acodec pcm_s16le '
        '"$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      return null;
    }

    final file = File(outputPath);
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    await file.delete(); // cleanup temp file

    // Convert Uint8List to Int16List (little-endian)
    return _bytesToInt16List(bytes);
  }

  /// Convert raw bytes to Int16List (little-endian)
  static Int16List _bytesToInt16List(Uint8List bytes) {
    final buffer = bytes.buffer;
    return buffer.asInt16List(bytes.offsetInBytes, bytes.length ~/ 2);
  }

  /// Get duration in seconds from sample count
  static double getDuration(Int16List samples) {
    return samples.length / sampleRate;
  }
}
