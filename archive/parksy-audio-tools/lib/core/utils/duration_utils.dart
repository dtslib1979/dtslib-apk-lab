/// Duration formatting utilities
/// 중복 코드 제거, 일관된 포맷팅
extension DurationFormatting on Duration {
  /// Format as "MM:SS" or "HH:MM:SS" (e.g., "02:05" or "01:30:05")
  String get formatted {
    final h = inHours;
    final m = inMinutes % 60;
    final s = inSeconds % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Format as "M:SS" (e.g., "2:05")
  String toMmSs() {
    final m = inMinutes;
    final s = inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Format as "HH:MM:SS" for FFmpeg
  String toFfmpegTime() {
    final h = inHours;
    final m = inMinutes % 60;
    final s = inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  /// Format as "M분 S초" for Korean UI
  String toKorean() {
    final m = inMinutes;
    final s = inSeconds % 60;
    if (m > 0 && s > 0) return '$m분 $s초';
    if (m > 0) return '$m분';
    return '$s초';
  }
}

/// Integer seconds to Duration
extension IntToDuration on int {
  Duration get seconds => Duration(seconds: this);
  Duration get minutes => Duration(minutes: this);
}

/// Parse duration from string
class DurationUtils {
  /// Parse "mm:ss" or "hh:mm:ss" format
  static Duration? parse(String input) {
    if (input.isEmpty) return null;

    final parts = input.split(':').map(int.tryParse).toList();
    if (parts.any((p) => p == null)) return null;

    final nums = parts.whereType<int>().toList();
    if (nums.length == 2) {
      return Duration(minutes: nums[0], seconds: nums[1]);
    }
    if (nums.length == 3) {
      return Duration(hours: nums[0], minutes: nums[1], seconds: nums[2]);
    }
    return null;
  }
}
