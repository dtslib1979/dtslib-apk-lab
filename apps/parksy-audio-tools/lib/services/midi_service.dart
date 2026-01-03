import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/config/app_config.dart';
import '../core/result/result.dart';
import 'file_manager.dart';
import 'analytics_service.dart';
import 'connectivity_service.dart';

/// MIDI conversion service via cloud API
/// Uses Basic Pitch model on Cloud Run
class MidiService {
  static final MidiService _instance = MidiService._();
  static MidiService get instance => _instance;
  MidiService._();

  final FileManager _fileManager = FileManager.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.midiServerUrl,
    connectTimeout: AppConfig.apiConnectTimeout,
    receiveTimeout: AppConfig.apiReceiveTimeout,
  ));

  /// Check server health - returns true if server responds
  Future<bool> healthCheck() async {
    if (!ConnectivityService.instance.isOnline) return false;
    
    try {
      final response = await _dio.get(
        '/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Convert MP3 to MIDI via server
  /// [source] is for analytics: 'capture' or 'file'
  Future<Result<String>> convert(String mp3Path, {String source = 'file'}) async {
    // Check connectivity first
    if (!ConnectivityService.instance.isOnline) {
      return const Failure(
        '인터넷 연결이 필요합니다',
        code: ErrorCode.networkError,
      );
    }

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

    // Log conversion start
    _analytics.logMidiConversionStart(source);
    final stopwatch = Stopwatch()..start();

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
        _analytics.logMidiConversionError('server_${response.statusCode}');
        return Failure(
          '서버 오류: ${response.statusCode}',
          code: ErrorCode.serverError,
        );
      }

      // Validate response - handle both List<int> and Uint8List
      final data = response.data;
      if (data == null) {
        _analytics.logMidiConversionError('empty_response');
        return const Failure(
          'MIDI 데이터가 비어있습니다',
          code: ErrorCode.conversionFailed,
        );
      }

      // Convert to Uint8List safely
      final Uint8List midiBytes;
      if (data is Uint8List) {
        midiBytes = data;
      } else if (data is List<int>) {
        midiBytes = Uint8List.fromList(data);
      } else {
        _analytics.logMidiConversionError('invalid_response_type');
        return const Failure(
          '잘못된 응답 형식입니다',
          code: ErrorCode.conversionFailed,
        );
      }

      if (midiBytes.isEmpty) {
        _analytics.logMidiConversionError('empty_midi');
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

      await File(midiPath).writeAsBytes(midiBytes);
      
      // Log success
      stopwatch.stop();
      _analytics.logMidiConversionSuccess(stopwatch.elapsedMilliseconds);
      
      return Success(midiPath);
    } on DioException catch (e) {
      stopwatch.stop();
      final errorCode = _getDioErrorCode(e);
      _analytics.logMidiConversionError(errorCode.name);
      _analytics.recordError(e, e.stackTrace, reason: 'MIDI conversion failed');
      
      return Failure(
        _parseDioError(e),
        code: errorCode,
      );
    } catch (e, stack) {
      stopwatch.stop();
      _analytics.logMidiConversionError('unknown');
      _analytics.recordError(e, stack, reason: 'MIDI conversion exception');
      
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
        if (code == 429) return '요청이 너무 많습니다. 잠시 후 다시 시도하세요';
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
