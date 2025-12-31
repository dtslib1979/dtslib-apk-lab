/// Duration formatting utilities
/// 중복 코드 제거, 일관된 포맷팅
extension DurationUtils on Duration {
  /// Format as "M:SS" (e.g., "2:05")
  String toMmSs() {
    final m = inMinutes;
    final s = inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Format as "HH:MM:SS" for FFmpeg
  String toFfmpegTime() {
    final h = inHours;
    final m = (inMinutes % 60);
    final s = (inSeconds % 60);
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
