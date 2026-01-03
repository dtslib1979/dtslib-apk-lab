import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/services/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    late ConnectivityService service;

    setUp(() {
      service = ConnectivityService.instance;
    });

    test('singleton pattern returns same instance', () {
      final instance1 = ConnectivityService.instance;
      final instance2 = ConnectivityService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('isOnline returns boolean', () {
      // Before init, default is true
      expect(service.isOnline, isA<bool>());
    });

    test('canConvertMidi returns same as isOnline', () {
      expect(service.canConvertMidi, equals(service.isOnline));
    });

    test('onConnectivityChanged returns Stream', () {
      expect(service.onConnectivityChanged, isA<Stream<bool>>());
    });
  });
}
