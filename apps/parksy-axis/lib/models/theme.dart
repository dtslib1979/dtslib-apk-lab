import 'package:flutter/material.dart';

/// 테마 프리셋 - 6개 색상 팔레트
class AxisTheme {
  final String id;
  final String name;
  final Color accent;
  final Color bg;
  final Color text;
  final Color dim;

  const AxisTheme({
    required this.id,
    required this.name,
    required this.accent,
    required this.bg,
    required this.text,
    required this.dim,
  });

  static const presets = [
    AxisTheme(
      id: 'amber',
      name: 'Amber',
      accent: Color(0xFFFFB300),
      bg: Color(0xFF0D0D0D),
      text: Color(0xFFBDBDBD),
      dim: Color(0xFF757575),
    ),
    AxisTheme(
      id: 'cyan',
      name: 'Cyan',
      accent: Color(0xFF00BCD4),
      bg: Color(0xFF0A1A1F),
      text: Color(0xFFB2EBF2),
      dim: Color(0xFF4DD0E1),
    ),
    AxisTheme(
      id: 'lime',
      name: 'Lime',
      accent: Color(0xFFCDDC39),
      bg: Color(0xFF0F1A0A),
      text: Color(0xFFF0F4C3),
      dim: Color(0xFFAED581),
    ),
    AxisTheme(
      id: 'rose',
      name: 'Rose',
      accent: Color(0xFFFF4081),
      bg: Color(0xFF1A0A0F),
      text: Color(0xFFF8BBD9),
      dim: Color(0xFFF06292),
    ),
    AxisTheme(
      id: 'violet',
      name: 'Violet',
      accent: Color(0xFFB388FF),
      bg: Color(0xFF12071F),
      text: Color(0xFFD1C4E9),
      dim: Color(0xFF9575CD),
    ),
    AxisTheme(
      id: 'mono',
      name: 'Mono',
      accent: Color(0xFFFFFFFF),
      bg: Color(0xFF121212),
      text: Color(0xFFE0E0E0),
      dim: Color(0xFF9E9E9E),
    ),
  ];

  static AxisTheme byId(String id) =>
      presets.firstWhere((t) => t.id == id, orElse: () => presets.first);
}

/// 폰트 프리셋 - 5개 타입페이스
class AxisFont {
  final String id;
  final String name;
  final String family;

  const AxisFont({required this.id, required this.name, required this.family});

  static const presets = [
    AxisFont(id: 'mono', name: 'Mono', family: 'monospace'),
    AxisFont(id: 'sans', name: 'Sans', family: 'sans-serif'),
    AxisFont(id: 'serif', name: 'Serif', family: 'serif'),
    AxisFont(id: 'cond', name: 'Condensed', family: 'sans-serif-condensed'),
    AxisFont(id: 'round', name: 'Rounded', family: 'sans-serif-medium'),
  ];

  static AxisFont byId(String id) =>
      presets.firstWhere((f) => f.id == id, orElse: () => presets.first);
}
