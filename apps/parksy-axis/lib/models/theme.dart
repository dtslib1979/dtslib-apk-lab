/// Parksy Axis v9.0.0 - 테마 시스템
/// 그라데이션 지원 + 확장된 색상 팔레트

import 'package:flutter/material.dart';

/// 테마 프리셋 - 8개 색상 팔레트 + 그라데이션
@immutable
class AxisTheme {
  final String id;
  final String name;
  final Color accent;
  final Color accentLight;
  final Color bg;
  final Color bgSecondary;
  final Color text;
  final Color dim;
  final Color highlight;

  const AxisTheme({
    required this.id,
    required this.name,
    required this.accent,
    required this.accentLight,
    required this.bg,
    required this.bgSecondary,
    required this.text,
    required this.dim,
    required this.highlight,
  });

  /// 액센트 그라데이션
  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accentLight, accent],
      );

  /// 배경 그라데이션
  LinearGradient get bgGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bg, bgSecondary],
      );

  /// 글로우 효과 색상
  Color get glow => accent.withOpacity(0.3);

  /// 프리셋 테마들
  static const List<AxisTheme> presets = [
    // Amber - 기본 골드
    AxisTheme(
      id: 'amber',
      name: 'Amber',
      accent: Color(0xFFFFB300),
      accentLight: Color(0xFFFFD54F),
      bg: Color(0xFF0D0D0D),
      bgSecondary: Color(0xFF1A1A1A),
      text: Color(0xFFE0E0E0),
      dim: Color(0xFF757575),
      highlight: Color(0xFFFFF8E1),
    ),
    // Cyan - 시안 블루
    AxisTheme(
      id: 'cyan',
      name: 'Cyan',
      accent: Color(0xFF00BCD4),
      accentLight: Color(0xFF4DD0E1),
      bg: Color(0xFF0A1A1F),
      bgSecondary: Color(0xFF102830),
      text: Color(0xFFE0F7FA),
      dim: Color(0xFF4DB6AC),
      highlight: Color(0xFFB2EBF2),
    ),
    // Lime - 라임 그린
    AxisTheme(
      id: 'lime',
      name: 'Lime',
      accent: Color(0xFFCDDC39),
      accentLight: Color(0xFFE6EE9C),
      bg: Color(0xFF0F1A0A),
      bgSecondary: Color(0xFF1A2810),
      text: Color(0xFFF0F4C3),
      dim: Color(0xFFAED581),
      highlight: Color(0xFFF9FBE7),
    ),
    // Rose - 로즈 핑크
    AxisTheme(
      id: 'rose',
      name: 'Rose',
      accent: Color(0xFFFF4081),
      accentLight: Color(0xFFFF80AB),
      bg: Color(0xFF1A0A0F),
      bgSecondary: Color(0xFF2A1018),
      text: Color(0xFFFCE4EC),
      dim: Color(0xFFF06292),
      highlight: Color(0xFFF8BBD9),
    ),
    // Violet - 바이올렛
    AxisTheme(
      id: 'violet',
      name: 'Violet',
      accent: Color(0xFFB388FF),
      accentLight: Color(0xFFD1C4E9),
      bg: Color(0xFF12071F),
      bgSecondary: Color(0xFF1D0F30),
      text: Color(0xFFEDE7F6),
      dim: Color(0xFF9575CD),
      highlight: Color(0xFFE1BEE7),
    ),
    // Ocean - 오션 블루
    AxisTheme(
      id: 'ocean',
      name: 'Ocean',
      accent: Color(0xFF2196F3),
      accentLight: Color(0xFF64B5F6),
      bg: Color(0xFF0A1525),
      bgSecondary: Color(0xFF0F1F35),
      text: Color(0xFFE3F2FD),
      dim: Color(0xFF42A5F5),
      highlight: Color(0xFFBBDEFB),
    ),
    // Sunset - 선셋 오렌지
    AxisTheme(
      id: 'sunset',
      name: 'Sunset',
      accent: Color(0xFFFF5722),
      accentLight: Color(0xFFFF8A65),
      bg: Color(0xFF1A0F0A),
      bgSecondary: Color(0xFF2A1810),
      text: Color(0xFFFBE9E7),
      dim: Color(0xFFFF7043),
      highlight: Color(0xFFFFCCBC),
    ),
    // Mono - 모노크롬
    AxisTheme(
      id: 'mono',
      name: 'Mono',
      accent: Color(0xFFFFFFFF),
      accentLight: Color(0xFFF5F5F5),
      bg: Color(0xFF121212),
      bgSecondary: Color(0xFF1E1E1E),
      text: Color(0xFFE0E0E0),
      dim: Color(0xFF9E9E9E),
      highlight: Color(0xFFFAFAFA),
    ),
  ];

  /// ID로 테마 찾기
  static AxisTheme byId(String id) =>
      presets.firstWhere((t) => t.id == id, orElse: () => presets.first);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AxisTheme && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// 폰트 프리셋 - 6개 타입페이스
@immutable
class AxisFont {
  final String id;
  final String name;
  final String family;
  final FontWeight weight;

  const AxisFont({
    required this.id,
    required this.name,
    required this.family,
    this.weight = FontWeight.normal,
  });

  /// 폰트 스타일 생성
  TextStyle style({
    double? size,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      color: color,
      fontWeight: fontWeight ?? weight,
    );
  }

  static const List<AxisFont> presets = [
    AxisFont(id: 'mono', name: 'Mono', family: 'monospace'),
    AxisFont(id: 'sans', name: 'Sans', family: 'sans-serif'),
    AxisFont(id: 'serif', name: 'Serif', family: 'serif'),
    AxisFont(id: 'cond', name: 'Condensed', family: 'sans-serif-condensed'),
    AxisFont(id: 'round', name: 'Rounded', family: 'sans-serif-medium'),
    AxisFont(
      id: 'bold',
      name: 'Bold',
      family: 'sans-serif',
      weight: FontWeight.bold,
    ),
  ];

  static AxisFont byId(String id) =>
      presets.firstWhere((f) => f.id == id, orElse: () => presets.first);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AxisFont && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
