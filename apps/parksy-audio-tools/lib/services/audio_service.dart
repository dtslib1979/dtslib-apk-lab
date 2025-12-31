import 'dart:io';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import '../core/config/app_config.dart';
import '../core/result/result.dart';
import '../core/utils/duration_utils.dart';
import 'file_manager.dart';

/// Audio processing service
/// - Trim with preset/custom duration
/// - Encode to MP3
/// - WAV output for legacy trimmer
class AudioService {
  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;
  AudioService._();

  final FileManager _fileManager = FileManager.instance;

  /// Trim audio to specified duration (stream copy, fast)
  Future<Result<String>> trim({
    required String inputPath,
    required Duration start,
    required Duration duration,
  }) async {
    // Validate input
    if (!await _fileManager.exists(inputPath)) {
      return const Failure(
        '입력 파일을 찾을 수 없습니다',
        code: ErrorCode.fileNotFound,
      );
    }

    // Validate duration
    if (duration.inSeconds > AppConfig.maxDurationSeconds) {
      return Failure(
        '최대 ${AppConfig.maxDurationSeconds ~/ 60}분까지만 지원합니다',
        code: ErrorCode.invalidFormat,
      );
    }

    try {
      final outputPath = await _fileManager.createTempPath(
        extension: 'wav',
        prefix: 'trimmed_',
      );

      final cmd = '-y -i "$inputPath" '
          '-ss ${start.toFfmpegTime()} '
          '-t ${duration.toFfmpegTime()} '
          '-c copy "$outputPath"';

      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getLogsAsString();
        return Failure(
          '트림 실패: ${_parseFFmpegError(logs)}',
          code: ErrorCode.trimFailed,
        );
      }

      return Success(outputPath);
    } catch (e) {
      return Failure('트림 중 오류: $e', code: ErrorCode.trimFailed);
    }
  }

  /// Trim to WAV with re-encoding (legacy trimmer)
  Future<Result<String>> trimToWav({
    required String inputPath,
    required Duration start,
    required Duration duration,
  }) async {
    if (!await _fileManager.exists(inputPath)) {
      return const Failure(
        '입력 파일을 찾을 수 없습니다',
        code: ErrorCode.fileNotFound,
      );
    }

    try {
      final outputPath = await _fileManager.createTempPath(
        extension: 'wav',
        prefix: 'output_',
      );

      final cmd = '-y -i "$inputPath" '
          '-ss ${start.toFfmpegTime()} '
          '-t ${duration.toFfmpegTime()} '
          '-acodec pcm_s16le '
          '-ar ${AppConfig.wavSampleRate} '
          '"$outputPath"';

      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        return const Failure('WAV 변환 실패', code: ErrorCode.encodingFailed);
      }

      return Success(outputPath);
    } catch (e) {
      return Failure('WAV 변환 중 오류: $e', code: ErrorCode.encodingFailed);
    }
  }

  /// Convert any audio to MP3
  Future<Result<String>> toMp3(String inputPath) async {
    if (!await _fileManager.exists(inputPath)) {
      return const Failure(
        '입력 파일을 찾을 수 없습니다',
        code: ErrorCode.fileNotFound,
      );
    }

    try {
      final outputPath = await _fileManager.createTempPath(
        extension: 'mp3',
        prefix: 'audio_',
      );

      final cmd = '-y -i "$inputPath" '
          '-acodec libmp3lame '
          '-q:a ${AppConfig.mp3Quality} '
          '"$outputPath"';

      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        return const Failure('MP3 변환 실패', code: ErrorCode.encodingFailed);
      }

      return Success(outputPath);
    } catch (e) {
      return Failure('MP3 변환 중 오류: $e', code: ErrorCode.encodingFailed);
    }
  }

  /// Full pipeline: Trim → MP3
  Future<Result<String>> trimAndEncode({
    required String inputPath,
    required Duration start,
    required Duration duration,
  }) async {
    // Step 1: Trim
    final trimResult = await trim(
      inputPath: inputPath,
      start: start,
      duration: duration,
    );

    if (trimResult.isFailure) return trimResult;
    final trimmedPath = trimResult.valueOrNull!;

    // Step 2: Encode
    final mp3Result = await toMp3(trimmedPath);

    // Cleanup intermediate file
    await _fileManager.delete(trimmedPath);

    return mp3Result;
  }

  /// Parse FFmpeg error for user-friendly message
  String _parseFFmpegError(String? logs) {
    if (logs == null) return '알 수 없는 오류';

    if (logs.contains('No such file')) return '파일을 찾을 수 없습니다';
    if (logs.contains('Invalid data')) return '손상된 오디오 파일';
    if (logs.contains('Permission denied')) return '파일 접근 권한 없음';

    return '인코딩 오류';
  }

  // === Legacy static methods for backward compatibility ===
  // TODO: Remove after all screens are refactored

  static Future<String> trim_legacy(
    String input,
    Duration start,
    Duration duration,
  ) async {
    final result = await instance.trim(
      inputPath: input,
      start: start,
      duration: duration,
    );
    return result.fold(
      onSuccess: (path) => path,
      onFailure: (error, _) => throw Exception(error),
    );
  }

  static Future<String> trimToWav_legacy(
    String input,
    Duration start,
    Duration duration,
  ) async {
    final result = await instance.trimToWav(
      inputPath: input,
      start: start,
      duration: duration,
    );
    return result.fold(
      onSuccess: (path) => path,
      onFailure: (error, _) => throw Exception(error),
    );
  }

  static Future<String> toMp3_legacy(String input) async {
    final result = await instance.toMp3(input);
    return result.fold(
      onSuccess: (path) => path,
      onFailure: (error, _) => throw Exception(error),
    );
  }
}
