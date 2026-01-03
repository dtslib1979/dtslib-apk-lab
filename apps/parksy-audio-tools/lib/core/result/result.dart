/// Result type for explicit error handling
/// Either Success<T> or Failure with error details
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
    Success(value: final v) => v,
    Failure() => null,
  };

  String? get errorOrNull => switch (this) {
    Success() => null,
    Failure(error: final e) => e,
  };

  ErrorCode? get codeOrNull => switch (this) {
    Success() => null,
    Failure(code: final c) => c,
  };

  /// Transform success value
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(value: final v) => Success(transform(v)),
      Failure(error: final e, code: final c) => Failure(e, code: c),
    };
  }

  /// Chain async operations
  Future<Result<R>> flatMap<R>(Future<Result<R>> Function(T value) transform) async {
    return switch (this) {
      Success(value: final v) => await transform(v),
      Failure(error: final e, code: final c) => Failure(e, code: c),
    };
  }

  /// Handle both cases
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(String error, ErrorCode? code) onFailure,
  }) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(error: final e, code: final c) => onFailure(e, c),
    };
  }

  /// Get value or throw
  T getOrThrow() {
    return switch (this) {
      Success(value: final v) => v,
      Failure(error: final e) => throw Exception(e),
    };
  }

  /// Get value or default
  T getOrElse(T defaultValue) {
    return switch (this) {
      Success(value: final v) => v,
      Failure() => defaultValue,
    };
  }
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final String error;
  final ErrorCode? code;
  const Failure(this.error, {this.code});

  /// Check if error is retryable
  bool get isRetryable => switch (code) {
    ErrorCode.networkError => true,
    ErrorCode.timeout => true,
    ErrorCode.serverError => true,
    ErrorCode.rateLimited => true,
    _ => false,
  };
}

/// Error categories for better handling
enum ErrorCode {
  // Permission
  permissionDenied,
  permissionPermanentlyDenied,

  // Recording
  recordingNotStarted,
  recordingFailed,
  recordingStopped,

  // File
  fileNotFound,
  fileReadError,
  fileWriteError,
  invalidFormat,
  fileTooLarge,

  // Processing
  trimFailed,
  encodingFailed,
  conversionFailed,

  // Network
  networkError,
  serverError,
  timeout,
  rateLimited,
  offline,

  // Unknown
  unknown,
}

/// Extension for easy Result creation
extension ResultExtension<T> on T {
  Result<T> asSuccess() => Success(this);
}

extension FutureResultExtension<T> on Future<T> {
  Future<Result<T>> toResult({
    String Function(Object e)? onError,
    ErrorCode? code,
  }) async {
    try {
      return Success(await this);
    } catch (e) {
      return Failure(
        onError?.call(e) ?? e.toString(),
        code: code ?? ErrorCode.unknown,
      );
    }
  }
}

/// Extension for ErrorCode user messages
extension ErrorCodeMessage on ErrorCode {
  String get userMessage => switch (this) {
    ErrorCode.permissionDenied => '권한이 필요합니다',
    ErrorCode.permissionPermanentlyDenied => '설정에서 권한을 허용해주세요',
    ErrorCode.recordingNotStarted => '녹음이 시작되지 않았습니다',
    ErrorCode.recordingFailed => '녹음 실패',
    ErrorCode.recordingStopped => '녹음이 중단되었습니다',
    ErrorCode.fileNotFound => '파일을 찾을 수 없습니다',
    ErrorCode.fileReadError => '파일을 읽을 수 없습니다',
    ErrorCode.fileWriteError => '파일 저장 실패',
    ErrorCode.invalidFormat => '지원하지 않는 형식입니다',
    ErrorCode.fileTooLarge => '파일이 너무 큽니다',
    ErrorCode.trimFailed => '트림 실패',
    ErrorCode.encodingFailed => '인코딩 실패',
    ErrorCode.conversionFailed => '변환 실패',
    ErrorCode.networkError => '네트워크 오류',
    ErrorCode.serverError => '서버 오류',
    ErrorCode.timeout => '시간 초과',
    ErrorCode.rateLimited => '요청이 너무 많습니다',
    ErrorCode.offline => '오프라인 상태입니다',
    ErrorCode.unknown => '알 수 없는 오류',
  };
}
