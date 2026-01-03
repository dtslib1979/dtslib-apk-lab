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
      expect(result.message, '테스트 에러');
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
    });
  });
}
