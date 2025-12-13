import 'dart:ui';

class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final DateTime createdAt;
  double opacity;

  Stroke({
    required this.points,
    this.color = const Color(0xFFFFFFFF),
    this.width = 4.0,
    DateTime? createdAt,
    this.opacity = 1.0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 3초 경과 여부
  bool get shouldFade {
    final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
    return elapsed >= 3000;
  }

  /// 페이드아웃 진행률 (3초~3.5초 구간)
  double get fadeProgress {
    final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
    if (elapsed < 3000) return 0.0;
    if (elapsed > 3500) return 1.0;
    return (elapsed - 3000) / 500.0;
  }

  /// 현재 투명도 계산
  double get currentOpacity {
    return (1.0 - fadeProgress).clamp(0.0, 1.0);
  }

  /// 완전히 사라졌는지 여부
  bool get isExpired {
    return DateTime.now().difference(createdAt).inMilliseconds > 3500;
  }

  Stroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    double? opacity,
  }) {
    return Stroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      createdAt: createdAt,
      opacity: opacity ?? this.opacity,
    );
  }
}
