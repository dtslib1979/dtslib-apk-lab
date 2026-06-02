import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/core/result/result.dart';

void main() {
  group('Result', () {
    test('Success contains value', () {
      const result = Success<int>(42);
      
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.value, 42);
    });

    test('Failure contains message and code', () {
      const result = Failure<int>(
        '테스트 에러',
        code: ErrorCode.networkError,
      );
      
      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.error, '테스트 에러');
      expect(result.code, ErrorCode.networkError);
    });

    test('fold executes onSuccess for Success', () {
      const result = Success<int>(10);
      
      final output = result.fold(
        onSuccess: (v) => 'value: $v',
        onFailure: (m, c) => 'error: $m',
      );
      
      expect(output, 'value: 10');
    });

    test('fold executes onFailure for Failure', () {
      const result = Failure<int>('failed', code: ErrorCode.unknown);
      
      final output = result.fold(
        onSuccess: (v) => 'value: $v',
        onFailure: (m, c) => 'error: $m',
      );
      
      expect(output, 'error: failed');
    });

    test('map transforms Success value', () {
      const result = Success<int>(5);
      
      final mapped = result.map((v) => v * 2);
      
      expect(mapped.isSuccess, true);
      expect((mapped as Success<int>).value, 10);
    });

    test('map preserves Failure', () {
      const result = Failure<int>('err', code: ErrorCode.fileNotFound);
      
      final mapped = result.map((v) => v * 2);
      
      expect(mapped.isFailure, true);
      expect((mapped as Failure<int>).code, ErrorCode.fileNotFound);
    });

    test('getOrElse returns value on Success', () {
      const result = Success<int>(42);
      expect(result.getOrElse(0), 42);
    });

    test('getOrElse returns default on Failure', () {
      const result = Failure<int>('error');
      expect(result.getOrElse(0), 0);
    });

    test('valueOrNull returns null on Failure', () {
      const result = Failure<int>('error');
      expect(result.valueOrNull, isNull);
    });

    test('codeOrNull returns code on Failure', () {
      const result = Failure<int>('error', code: ErrorCode.timeout);
      expect(result.codeOrNull, ErrorCode.timeout);
    });
  });

  group('Failure', () {
    test('isRetryable true for network errors', () {
      const result = Failure<int>('err', code: ErrorCode.networkError);
      expect(result.isRetryable, true);
    });

    test('isRetryable true for timeout', () {
      const result = Failure<int>('err', code: ErrorCode.timeout);
      expect(result.isRetryable, true);
    });

    test('isRetryable true for rate limited', () {
      const result = Failure<int>('err', code: ErrorCode.rateLimited);
      expect(result.isRetryable, true);
    });

    test('isRetryable false for file errors', () {
      const result = Failure<int>('err', code: ErrorCode.fileNotFound);
      expect(result.isRetryable, false);
    });

    test('isRetryable false for permission errors', () {
      const result = Failure<int>('err', code: ErrorCode.permissionDenied);
      expect(result.isRetryable, false);
    });
  });

  group('ErrorCode', () {
    test('all error codes have unique values', () {
      final codes = ErrorCode.values;
      final names = codes.map((c) => c.name).toSet();
      
      expect(names.length, codes.length);
    });

    test('critical error codes exist', () {
      expect(ErrorCode.values.contains(ErrorCode.networkError), true);
      expect(ErrorCode.values.contains(ErrorCode.conversionFailed), true);
      expect(ErrorCode.values.contains(ErrorCode.permissionDenied), true);
      expect(ErrorCode.values.contains(ErrorCode.serverError), true);
      expect(ErrorCode.values.contains(ErrorCode.rateLimited), true);
      expect(ErrorCode.values.contains(ErrorCode.offline), true);
    });

    test('userMessage returns Korean text', () {
      expect(ErrorCode.networkError.userMessage, contains('네트워크'));
      expect(ErrorCode.timeout.userMessage, contains('시간'));
      expect(ErrorCode.rateLimited.userMessage, contains('요청'));
    });
  });

  group('Extensions', () {
    test('asSuccess wraps value', () {
      final result = 42.asSuccess();
      expect(result.isSuccess, true);
      expect(result.valueOrNull, 42);
    });

    test('toResult catches exceptions', () async {
      final future = Future<int>.error('test error');
      final result = await future.toResult(
        onError: (e) => 'caught: $e',
        code: ErrorCode.unknown,
      );
      
      expect(result.isFailure, true);
      expect(result.errorOrNull, 'caught: test error');
    });
  });
}
