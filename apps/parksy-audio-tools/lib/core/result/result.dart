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
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final String error;
  final ErrorCode? code;
  const Failure(this.error, {this.code});
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

  // Processing
  trimFailed,
  encodingFailed,
  conversionFailed,

  // Network
  networkError,
  serverError,
  timeout,

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
