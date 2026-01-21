/// Parksy Axis v9.0.0 - 유틸 확장 함수
/// Dart 표준 타입에 대한 편의 확장

import 'package:flutter/material.dart';

/// Color 확장
extension ColorX on Color {
  /// 밝기 조절 (-1.0 ~ 1.0)
  Color brighten(double amount) {
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// 투명도 적용 (0.0 ~ 1.0)
  Color fade(double opacity) => withOpacity(opacity.clamp(0.0, 1.0));

  /// 그라데이션 생성
  LinearGradient toGradient({
    double darken = 0.2,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [this, brighten(-darken)],
    );
  }
}

/// String 확장
extension StringX on String {
  /// 빈 문자열이면 기본값 반환
  String orDefault(String defaultValue) => isEmpty ? defaultValue : this;

  /// 최대 길이로 자르기 (말줄임표 추가)
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - 1)}…';
  }
}

/// List 확장
extension ListX<T> on List<T> {
  /// 안전한 인덱스 접근
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// 순환 인덱스 접근
  T getCircular(int index) => this[index % length];

  /// 다음 인덱스 (순환)
  int nextIndex(int current) => (current + 1) % length;

  /// 이전 인덱스 (순환)
  int prevIndex(int current) => (current - 1 + length) % length;
}

/// num 확장
extension NumX on num {
  /// 범위 제한
  double clampDouble(double min, double max) => toDouble().clamp(min, max);

  /// 밀리초를 Duration으로
  Duration get ms => Duration(milliseconds: toInt());

  /// 초를 Duration으로
  Duration get seconds => Duration(seconds: toInt());
}

/// Duration 확장
extension DurationX on Duration {
  /// Future.delayed 축약
  Future<void> get delay => Future.delayed(this);
}

/// BuildContext 확장
extension ContextX on BuildContext {
  /// 화면 크기
  Size get screenSize => MediaQuery.sizeOf(this);

  /// 화면 너비
  double get screenWidth => screenSize.width;

  /// 화면 높이
  double get screenHeight => screenSize.height;

  /// 테마
  ThemeData get theme => Theme.of(this);

  /// 텍스트 테마
  TextTheme get textTheme => theme.textTheme;

  /// 스낵바 표시
  void showSnackBar(String message, {Color? color}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// 네비게이션 - push
  Future<T?> push<T>(Widget page) {
    return Navigator.push<T>(
      this,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// 네비게이션 - pop
  void pop<T>([T? result]) => Navigator.pop(this, result);
}
