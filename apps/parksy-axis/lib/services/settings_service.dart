import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정 모델 - v5 스키마
class AxisSettings {
  String rootName;
  List<String> stages;
  String position;
  int width;
  int height;
  String themeId;
  String fontId;
  double bgOpacity;
  double strokeWidth;
  double overlayScale;

  AxisSettings({
    this.rootName = '[Idea]',
    List<String>? stages,
    this.position = 'bottomLeft',
    this.width = 260,
    this.height = 300,
    this.themeId = 'amber',
    this.fontId = 'mono',
    this.bgOpacity = 0.9,
    this.strokeWidth = 1.5,
    this.overlayScale = 1.0,
  }) : stages = stages ?? ['Capture', 'Note', 'Build', 'Test', 'Publish'];

  Map<String, dynamic> toJson() => {
        'root': rootName,
        'stages': stages,
        'pos': position,
        'w': width,
        'h': height,
        'theme': themeId,
        'font': fontId,
        'opacity': bgOpacity,
        'stroke': strokeWidth,
        'scale': overlayScale,
      };

  factory AxisSettings.fromJson(Map<String, dynamic> j) => AxisSettings(
        rootName: j['root'] ?? '[Idea]',
        stages: j['stages'] != null ? List<String>.from(j['stages']) : null,
        position: j['pos'] ?? 'bottomLeft',
        width: j['w'] ?? 260,
        height: j['h'] ?? 300,
        themeId: j['theme'] ?? 'amber',
        fontId: j['font'] ?? 'mono',
        bgOpacity: (j['opacity'] ?? 0.9).toDouble(),
        strokeWidth: (j['stroke'] ?? 1.5).toDouble(),
        overlayScale: (j['scale'] ?? 1.0).toDouble(),
      );

  AxisSettings copy({
    String? rootName,
    List<String>? stages,
    String? position,
    int? width,
    int? height,
    String? themeId,
    String? fontId,
    double? bgOpacity,
    double? strokeWidth,
    double? overlayScale,
  }) =>
      AxisSettings(
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

/// 설정 저장소 - SharedPreferences 래퍼
class SettingsService {
  static const _key = 'axis_v5';
  static AxisSettings? _cache;

  static Future<AxisSettings> load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _cache = AxisSettings.fromJson(jsonDecode(raw));
      } catch (_) {
        _cache = AxisSettings();
      }
    } else {
      _cache = AxisSettings();
    }
    return _cache!;
  }

  static Future<void> save(AxisSettings s) async {
    _cache = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }

  static void clear() => _cache = null;
}
