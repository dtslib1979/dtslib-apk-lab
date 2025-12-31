import 'dart:io';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  /// Trim audio and output as temp file
  static Future<String> trim(
    String input,
    Duration start,
    Duration duration,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final out = '${dir.path}/trimmed_$ts.wav';

    final ss = _fmtSec(start.inSeconds);
    final t = _fmtSec(duration.inSeconds);

    final cmd = '-y -i "$input" -ss $ss -t $t -c copy "$out"';
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();

    if (!ReturnCode.isSuccess(code)) {
      throw Exception('Trim failed');
    }

    return out;
  }

  /// Trim to WAV (for legacy trimmer)
  static Future<String> trimToWav(
    String input,
    Duration start,
    Duration duration,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final out = '${dir.path}/output_$ts.wav';

    final ss = _fmtSec(start.inSeconds);
    final t = _fmtSec(duration.inSeconds);

    final cmd = '-y -i "$input" -ss $ss -t $t '
        '-acodec pcm_s16le -ar 44100 "$out"';
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();

    if (!ReturnCode.isSuccess(code)) {
      throw Exception('Trim to WAV failed');
    }

    return out;
  }

  /// Convert to MP3
  static Future<String> toMp3(String input) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final out = '${dir.path}/audio_$ts.mp3';

    final cmd = '-y -i "$input" -acodec libmp3lame -q:a 2 "$out"';
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();

    if (!ReturnCode.isSuccess(code)) {
      throw Exception('MP3 conversion failed');
    }

    return out;
  }

  static String _fmtSec(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}
