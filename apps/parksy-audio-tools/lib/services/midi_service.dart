import 'dart:io';
import 'package:dio/dio.dart';
import '../core/config/app_config.dart';
import '../core/result/result.dart';
import 'file_manager.dart';

/// MIDI conversion service via cloud API
/// Uses Basic Pitch model on Cloud Run
class MidiService {
  static final MidiService _instance = MidiService._();
  static MidiService get instance => _instance;
  MidiService._();

  final FileManager _fileManager = FileManager.instance;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.midiServerUrl,
    connectTimeout: AppConfig.apiConnectTimeout,
    receiveTimeout: AppConfig.apiReceiveTimeout,
  ));

  /// Convert MP3 to MIDI via server
  Future<Result<String>> convert(String mp3Path) async {
    // Validate input
    if (!await _fileManager.exists(mp3Path)) {
      return const Failure(
        'MP3 파일을 찾을 수 없습니다',
        code: ErrorCode.fileNotFound,
      );
    }

    // Check file size for debugging
    final fileSize = await _fileManager.getSize(mp3Path);
    if (fileSize == null) {
      return const Failure(
        '파일 크기 확인 실패',
        code: ErrorCode.fileReadError,
      );
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          mp3Path,
          filename: 'audio.mp3',
        ),
      });

      final response = await _dio.post(
        '/convert',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        return Failure(
          '서버 오류: ${response.statusCode}',
          code: ErrorCode.serverError,
        );
      }

      // Validate response
      final data = response.data;
      if (data == null || (data as List).isEmpty) {
        return const Failure(
          'MIDI 데이터가 비어있습니다',
          code: ErrorCode.conversionFailed,
        );
      }

      // Save MIDI file
      final midiPath = await _fileManager.createTempPath(
        extension: 'mid',
        prefix: 'output_',
      );

      await File(midiPath).writeAsBytes(data);
      return Success(midiPath);
    } on DioException catch (e) {
      return Failure(
        _parseDioError(e),
        code: _getDioErrorCode(e),
      );
    } catch (e) {
      return Failure('MIDI 변환 실패: $e', code: ErrorCode.conversionFailed);
    }
  }

  String _parseDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '서버 연결 시간 초과';
      case DioExceptionType.sendTimeout:
        return '업로드 시간 초과';
      case DioExceptionType.receiveTimeout:
        return '응답 시간 초과 (파일이 너무 긴가요?)';
      case DioExceptionType.connectionError:
        return '인터넷 연결을 확인해주세요';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 413) return '파일이 너무 큽니다';
        if (code == 500) return '서버 내부 오류';
        return '서버 오류: $code';
      default:
        return '네트워크 오류: ${e.message}';
    }
  }

  ErrorCode _getDioErrorCode(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ErrorCode.timeout;
      case DioExceptionType.connectionError:
        return ErrorCode.networkError;
      default:
        return ErrorCode.serverError;
    }
  }

  // === Legacy static method for backward compatibility ===
  // TODO: Remove after all screens are refactored

  static Future<String> convert_legacy(String mp3Path) async {
    final result = await instance.convert(mp3Path);
    return result.fold(
      onSuccess: (path) => path,
      onFailure: (error, _) => throw Exception(error),
    );
  }
}

/// Result holder for full conversion pipeline
class ConversionResult {
  final String mp3Path;
  final String midiPath;

  const ConversionResult({
    required this.mp3Path,
    required this.midiPath,
  });
}
