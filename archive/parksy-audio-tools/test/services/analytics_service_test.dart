import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/services/analytics_service.dart';

void main() {
  group('AnalyticsService (Stub)', () {
    late AnalyticsService service;

    setUp(() async {
      service = AnalyticsService.instance;
      await service.init();
    });

    test('singleton pattern returns same instance', () {
      final instance1 = AnalyticsService.instance;
      final instance2 = AnalyticsService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('init completes without error', () async {
      // Should not throw even when called multiple times
      await service.init();
      await service.init();
    });

    test('logScreenView completes without error', () async {
      await expectLater(
        service.logScreenView('test_screen'),
        completes,
      );
    });

    test('logRecordingStart completes without error', () async {
      await expectLater(
        service.logRecordingStart(30),
        completes,
      );
    });

    test('logRecordingComplete completes without error', () async {
      await expectLater(
        service.logRecordingComplete(25),
        completes,
      );
    });

    test('logMidiConversionStart completes without error', () async {
      await expectLater(
        service.logMidiConversionStart('capture'),
        completes,
      );
    });

    test('logMidiConversionSuccess completes without error', () async {
      await expectLater(
        service.logMidiConversionSuccess(1500),
        completes,
      );
    });

    test('logMidiConversionError completes without error', () async {
      await expectLater(
        service.logMidiConversionError('network_error'),
        completes,
      );
    });

    test('logFileShare completes without error', () async {
      await expectLater(
        service.logFileShare('midi'),
        completes,
      );
    });

    test('recordError completes without error', () async {
      await expectLater(
        service.recordError(
          Exception('test error'),
          StackTrace.current,
          reason: 'test reason',
        ),
        completes,
      );
    });

    test('log completes without error', () {
      // Synchronous method, just verify no exception
      expect(() => service.log('test message'), returnsNormally);
    });

    test('setUserProperty completes without error', () async {
      await expectLater(
        service.setUserProperty('test_key', 'test_value'),
        completes,
      );
    });
  });
}
