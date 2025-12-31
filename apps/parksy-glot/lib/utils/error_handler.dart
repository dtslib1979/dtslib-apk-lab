import 'dart:async';
import 'dart:io';

/// 사용자 친화적 에러 메시지 변환
class ErrorHandler {
  static String getUserMessage(dynamic error) {
    if (error is SocketException) {
      return '인터넷 연결을 확인해주세요';
    }
    if (error is TimeoutException) {
      return '서버 응답이 느립니다. 다시 시도해주세요';
    }
    if (error is ApiException) {
      return error.userMessage;
    }
    if (error is AudioCaptureException) {
      return error.userMessage;
    }
    if (error is PermissionException) {
      return error.userMessage;
    }

    final msg = error.toString().toLowerCase();

    if (msg.contains('api key') || msg.contains('unauthorized') || msg.contains('401')) {
      return 'API 키가 올바르지 않습니다. 설정에서 확인해주세요';
    }
    if (msg.contains('rate limit') || msg.contains('429')) {
      return 'API 호출 한도 초과. 잠시 후 다시 시도해주세요';
    }
    if (msg.contains('insufficient') || msg.contains('quota')) {
      return 'API 크레딧이 부족합니다';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return '네트워크 연결을 확인해주세요';
    }
    if (msg.contains('permission')) {
      return '권한이 필요합니다. 설정에서 허용해주세요';
    }
    if (msg.contains('audio') || msg.contains('capture')) {
      return '오디오 캡처에 실패했습니다';
    }

    return '오류가 발생했습니다. 다시 시도해주세요';
  }

  /// 에러 로깅
  static void log(dynamic error, [StackTrace? stack]) {
    print('═══════════════════════════════════════');
    print('ERROR: $error');
    if (stack != null) {
      print('STACK: $stack');
    }
    print('═══════════════════════════════════════');
  }
}

/// API 관련 예외
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  ApiException(this.message, {this.statusCode, this.details});

  String get userMessage {
    switch (statusCode) {
      case 400:
        return '잘못된 요청입니다';
      case 401:
        return 'API 키를 확인해주세요';
      case 403:
        return '접근이 거부되었습니다';
      case 429:
        return 'API 호출 한도 초과. 잠시 후 다시 시도';
      case 500:
      case 502:
      case 503:
        return 'OpenAI 서버에 문제가 있습니다';
      default:
        return message;
    }
  }

  @override
  String toString() => 'ApiException[$statusCode]: $message';
}

/// 오디오 캡처 예외
class AudioCaptureException implements Exception {
  final String message;
  final AudioCaptureError type;

  AudioCaptureException(this.message, this.type);

  String get userMessage {
    switch (type) {
      case AudioCaptureError.notAvailable:
        return 'Android 10 이상에서만 사용 가능합니다';
      case AudioCaptureError.permissionDenied:
        return '화면 녹화 권한이 필요합니다';
      case AudioCaptureError.projectionFailed:
        return '화면 캡처 권한을 허용해주세요';
      case AudioCaptureError.recordingFailed:
        return '오디오 녹음 시작에 실패했습니다';
      case AudioCaptureError.appBlocked:
        return '이 앱은 오디오 캡처를 차단했습니다';
      default:
        return '오디오 캡처 오류';
    }
  }

  @override
  String toString() => 'AudioCaptureException[$type]: $message';
}

enum AudioCaptureError {
  notAvailable,
  permissionDenied,
  projectionFailed,
  recordingFailed,
  appBlocked,
  unknown,
}

/// 권한 예외
class PermissionException implements Exception {
  final String permission;
  final String message;

  PermissionException(this.permission, this.message);

  String get userMessage => '$permission 권한이 필요합니다';

  @override
  String toString() => 'PermissionException[$permission]: $message';
}

/// 네트워크 재시도 유틸리티
class RetryHelper {
  static Future<T> retry<T>({
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    var delay = initialDelay;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        final isLastAttempt = attempt == maxAttempts;
        final canRetry = shouldRetry?.call(e) ?? _isRetryable(e);

        if (isLastAttempt || !canRetry) {
          rethrow;
        }

        print('Retry attempt $attempt/$maxAttempts after ${delay.inSeconds}s');
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).toInt(),
        );
      }
    }

    throw Exception('Max retry attempts exceeded');
  }

  static bool _isRetryable(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is ApiException) {
      return error.statusCode == 429 ||
          error.statusCode == 500 ||
          error.statusCode == 502 ||
          error.statusCode == 503;
    }
    return false;
  }
}
