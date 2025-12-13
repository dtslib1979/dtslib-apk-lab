import 'dart:ui';

class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final DateTime createdAt;

  Stroke({
    required this.points,
    this.color = const Color(0xFFFFFFFF),
    this.width = 4.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 3초 경과 여부
  bool get shouldFade {
    final ms = DateTime.now().difference(createdAt).inMilliseconds;
    return ms >= 3000;
  }

  /// 페이드아웃 진행률 (3초~3.5초 구간)
  double get fadeProgress {
    final ms = DateTime.now().difference(createdAt).inMilliseconds;
    if (ms < 3000) return 0.0;
    if (ms > 3500) return 1.0;
    return (ms - 3000) / 500.0;
  }

  /// 현재 투명도
  double get currentOpacity {
    return (1.0 - fadeProgress).clamp(0.0, 1.0);
  }

  /// 완전히 사라졌는지
  bool get isExpired {
    return DateTime.now().difference(createdAt).inMilliseconds > 3500;
  }

  Stroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
  }) {
    return Stroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      createdAt: createdAt,
    );
  }
}
