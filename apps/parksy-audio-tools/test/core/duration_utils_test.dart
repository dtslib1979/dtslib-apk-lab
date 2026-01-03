import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/core/duration_utils.dart';

void main() {
  group('DurationUtils', () {
    test('formats zero duration', () {
      const duration = Duration.zero;
      expect(duration.formatted, '00:00');
    });

    test('formats seconds only', () {
      const duration = Duration(seconds: 45);
      expect(duration.formatted, '00:45');
    });

    test('formats minutes and seconds', () {
      const duration = Duration(minutes: 3, seconds: 15);
      expect(duration.formatted, '03:15');
    });

    test('formats hours', () {
      const duration = Duration(hours: 1, minutes: 30, seconds: 5);
      expect(duration.formatted, '01:30:05');
    });

    test('formats long durations', () {
      const duration = Duration(hours: 12, minutes: 59, seconds: 59);
      expect(duration.formatted, '12:59:59');
    });

    test('handles edge cases', () {
      const d1 = Duration(seconds: 59);
      expect(d1.formatted, '00:59');
      
      const d2 = Duration(minutes: 59, seconds: 59);
      expect(d2.formatted, '59:59');
    });
  });

  group('DurationParsing', () {
    test('parses mm:ss format', () {
      final duration = DurationUtils.parse('03:45');
      expect(duration?.inMinutes, 3);
      expect(duration?.inSeconds, 225);
    });

    test('parses hh:mm:ss format', () {
      final duration = DurationUtils.parse('01:30:00');
      expect(duration?.inHours, 1);
      expect(duration?.inMinutes, 90);
    });

    test('returns null for invalid format', () {
      expect(DurationUtils.parse('invalid'), null);
      expect(DurationUtils.parse(''), null);
      expect(DurationUtils.parse('1:2:3:4'), null);
    });
  });
}
