import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/core/utils/duration_utils.dart';

void main() {
  group('DurationFormatting', () {
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

    test('toMmSs format', () {
      const duration = Duration(minutes: 3, seconds: 5);
      expect(duration.toMmSs(), '3:05');
    });

    test('toKorean format', () {
      const d1 = Duration(minutes: 2, seconds: 30);
      expect(d1.toKorean(), '2분 30초');

      const d2 = Duration(minutes: 5);
      expect(d2.toKorean(), '5분');

      const d3 = Duration(seconds: 45);
      expect(d3.toKorean(), '45초');
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

  group('IntToDuration', () {
    test('converts int to seconds', () {
      expect(30.seconds.inSeconds, 30);
    });

    test('converts int to minutes', () {
      expect(5.minutes.inMinutes, 5);
      expect(5.minutes.inSeconds, 300);
    });
  });
}
