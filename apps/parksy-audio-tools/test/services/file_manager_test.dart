import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/services/file_manager.dart';

void main() {
  group('FileManager', () {
    late FileManager manager;

    setUp(() {
      manager = FileManager.instance;
    });

    test('is singleton', () {
      final instance1 = FileManager.instance;
      final instance2 = FileManager.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('exists returns false for non-existent path', () async {
      final result = await manager.exists('/non/existent/file.txt');
      expect(result, isFalse);
    });

    test('getSize returns null for non-existent file', () async {
      final result = await manager.getSize('/non/existent/file.txt');
      expect(result, isNull);
    });

    test('delete completes without error for non-existent file', () async {
      // Should not throw even if file doesn't exist
      await manager.delete('/non/existent/file.txt');
      // If we reach here, test passes
    });

    test('createTempPath generates valid path structure', () async {
      final path = await manager.createTempPath(
        extension: 'mp3',
        prefix: 'test_',
      );

      expect(path, contains('test_'));
      expect(path, endsWith('.mp3'));
    });

    test('createTempPath handles different extensions', () async {
      final mp3Path = await manager.createTempPath(extension: 'mp3');
      final midiPath = await manager.createTempPath(extension: 'mid');
      final wavPath = await manager.createTempPath(extension: 'wav');

      expect(mp3Path, endsWith('.mp3'));
      expect(midiPath, endsWith('.mid'));
      expect(wavPath, endsWith('.wav'));
    });

    test('cleanupOldFiles returns count', () async {
      // In test environment, should return 0 or more
      final deleted = await manager.cleanupOldFiles();
      expect(deleted, isA<int>());
      expect(deleted, greaterThanOrEqualTo(0));
    });
  });
}
