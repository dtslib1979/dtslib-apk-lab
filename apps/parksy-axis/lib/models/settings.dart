/// Parksy Axis v9.0.0 - 설정 모델
/// 타입 안전성 강화 + sealed class + immutable pattern

import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// 오버레이 위치 enum
enum OverlayPosition {
  topLeft('topLeft', '좌상'),
  topRight('topRight', '우상'),
  bottomLeft('bottomLeft', '좌하'),
  bottomRight('bottomRight', '우하');

  const OverlayPosition(this.value, this.label);
  final String value;
  final String label;

  static OverlayPosition fromString(String? value) {
    return OverlayPosition.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OverlayPosition.bottomLeft,
    );
  }
}

/// 설정 모델 - v9 스키마 (immutable)
@immutable
class AxisSettings {
  final String rootName;
  final List<String> stages;
  final OverlayPosition position;
  final int width;
  final int height;
  final String themeId;
  final String fontId;
  final double bgOpacity;
  final double strokeWidth;
  final double overlayScale;

  const AxisSettings({
    this.rootName = DefaultStages.rootName,
    this.stages = DefaultStages.stages,
    this.position = OverlayPosition.bottomLeft,
    this.width = OverlayDefaults.width,
    this.height = OverlayDefaults.height,
    this.themeId = 'amber',
    this.fontId = 'mono',
    this.bgOpacity = UIDefaults.bgOpacity,
    this.strokeWidth = UIDefaults.strokeWidth,
    this.overlayScale = OverlayDefaults.defaultScale,
  });

  /// JSON 직렬화
  Map<String, dynamic> toJson() => {
        'root': rootName,
        'stages': stages,
        'pos': position.value,
        'w': width,
        'h': height,
        'theme': themeId,
        'font': fontId,
        'opacity': bgOpacity,
        'stroke': strokeWidth,
        'overlayScale': overlayScale,
        'version': 9, // 스키마 버전
      };

  /// JSON 역직렬화 (안전한 파싱)
  factory AxisSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AxisSettings();

    return AxisSettings(
      rootName: _parseString(json['root'], DefaultStages.rootName),
      stages: _parseStringList(json['stages'], DefaultStages.stages),
      position: OverlayPosition.fromString(json['pos'] as String?),
      width: _parseInt(json['w'], OverlayDefaults.width),
      height: _parseInt(json['h'], OverlayDefaults.height),
      themeId: _parseString(json['theme'], 'amber'),
      fontId: _parseString(json['font'], 'mono'),
      bgOpacity: _parseDouble(json['opacity'], UIDefaults.bgOpacity),
      strokeWidth: _parseDouble(json['stroke'], UIDefaults.strokeWidth),
      overlayScale: _parseDouble(json['overlayScale'], OverlayDefaults.defaultScale),
    );
  }

  /// copyWith 패턴
  AxisSettings copyWith({
    String? rootName,
    List<String>? stages,
    OverlayPosition? position,
    int? width,
    int? height,
    String? themeId,
    String? fontId,
    double? bgOpacity,
    double? strokeWidth,
    double? overlayScale,
  }) {
    return AxisSettings(
      rootName: rootName ?? this.rootName,
      stages: stages ?? List.from(this.stages),
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      themeId: themeId ?? this.themeId,
      fontId: fontId ?? this.fontId,
      bgOpacity: bgOpacity ?? this.bgOpacity,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      overlayScale: overlayScale ?? this.overlayScale,
    );
  }

  /// 스케일 적용된 크기
  int get scaledWidth => (width * overlayScale).toInt();
  int get scaledHeight => (height * overlayScale).toInt();

  /// 유효성 검증
  bool get isValid => stages.isNotEmpty && rootName.isNotEmpty;

  @override
  String toString() => 'AxisSettings(root: $rootName, stages: ${stages.length}, theme: $themeId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AxisSettings &&
        other.rootName == rootName &&
        listEquals(other.stages, stages) &&
        other.position == position &&
        other.width == width &&
        other.height == height &&
        other.themeId == themeId &&
        other.fontId == fontId &&
        other.bgOpacity == bgOpacity &&
        other.strokeWidth == strokeWidth &&
        other.overlayScale == overlayScale;
  }

  @override
  int get hashCode => Object.hash(
        rootName,
        stages,
        position,
        width,
        height,
        themeId,
        fontId,
        bgOpacity,
        strokeWidth,
        overlayScale,
      );

  // 안전한 타입 파싱 헬퍼
  static String _parseString(dynamic value, String defaultValue) {
    if (value is String) return value;
    return defaultValue;
  }

  static int _parseInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static List<String> _parseStringList(dynamic value, List<String> defaultValue) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return defaultValue;
  }
}

/// 템플릿 모델
@immutable
class AxisTemplate {
  final String id;
  final String name;
  final bool isPreset;
  final AxisSettings settings;
  final DateTime? createdAt;

  const AxisTemplate({
    required this.id,
    required this.name,
    required this.isPreset,
    required this.settings,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isPreset': isPreset,
        'settings': settings.toJson(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory AxisTemplate.fromJson(Map<String, dynamic> json) => AxisTemplate(
        id: json['id'] as String? ?? 'unknown',
        name: json['name'] as String? ?? 'Unknown',
        isPreset: json['isPreset'] as bool? ?? false,
        settings: AxisSettings.fromJson(json['settings'] as Map<String, dynamic>?),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  AxisTemplate copyWith({
    String? id,
    String? name,
    bool? isPreset,
    AxisSettings? settings,
    DateTime? createdAt,
  }) {
    return AxisTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      isPreset: isPreset ?? this.isPreset,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AxisTemplate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 프리셋 템플릿 정의
abstract final class PresetTemplates {
  static const List<AxisTemplate> all = [
    AxisTemplate(
      id: 'default',
      name: '기본',
      isPreset: true,
      settings: AxisSettings(),
    ),
    AxisTemplate(
      id: 'broadcast',
      name: '방송용',
      isPreset: true,
      settings: AxisSettings(
        rootName: DefaultStages.broadcastRoot,
        stages: DefaultStages.broadcastStages,
        themeId: 'rose',
        fontId: 'sans',
        width: 280,
        height: 320,
      ),
    ),
    AxisTemplate(
      id: 'meeting',
      name: '회의용',
      isPreset: true,
      settings: AxisSettings(
        rootName: DefaultStages.meetingRoot,
        stages: DefaultStages.meetingStages,
        themeId: 'cyan',
        fontId: 'mono',
        width: 240,
        height: 280,
      ),
    ),
    AxisTemplate(
      id: 'dev',
      name: '개발용',
      isPreset: true,
      settings: AxisSettings(
        rootName: DefaultStages.devRoot,
        stages: DefaultStages.devStages,
        themeId: 'lime',
        fontId: 'mono',
      ),
    ),
  ];

  static AxisTemplate getById(String id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => all.first,
    );
  }
}
