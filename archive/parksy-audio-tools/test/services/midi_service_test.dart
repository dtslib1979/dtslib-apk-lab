import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/services/midi_service.dart';

void main() {
  group('MidiService', () {
    late MidiService service;

    setUp(() {
      service = MidiService.instance;
    });

    test('is singleton', () {
      final instance1 = MidiService.instance;
      final instance2 = MidiService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('healthCheck returns bool', () async {
      // In test environment, connectivity may not be available
      // Just verify it returns a bool without crashing
      final result = await service.healthCheck();
      expect(result, isA<bool>());
    });

    test('convert returns Failure for non-existent file', () async {
      final result = await service.convert('/non/existent/file.mp3');
      
      result.fold(
        onSuccess: (_) => fail('Should fail for non-existent file'),
        onFailure: (error, code) {
          expect(error, contains('찾을 수 없습니다'));
        },
      );
    });

    test('convert accepts source parameter', () async {
      // Verify method signature accepts source param
      // Actual conversion would fail without valid file
      final result = await service.convert(
        '/test.mp3',
        source: 'capture',
      );
      
      expect(result.isFailure, isTrue);
    });
  });
}
