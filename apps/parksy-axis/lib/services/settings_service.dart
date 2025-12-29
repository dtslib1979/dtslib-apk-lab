import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AxisSettings {
  String rootName;
  List<String> stages;
  String position;
  int width;
  int height;
  
  // v4.0 새 필드
  String themeId;
  String fontId;
  double bgOpacity;
  double strokeWidth;

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
  }) : stages = stages ?? ['Capture', 'Note', 'Build', 'Test', 'Publish'];

  Map<String, dynamic> toJson() => {
    'rootName': rootName,
    'stages': stages,
    'position': position,
    'width': width,
    'height': height,
    'themeId': themeId,
    'fontId': fontId,
    'bgOpacity': bgOpacity,
    'strokeWidth': strokeWidth,
  };

  factory AxisSettings.fromJson(Map<String, dynamic> j) {
    final list = j['stages'] as List?;
    return AxisSettings(
      rootName: j['rootName'] ?? '[Idea]',
      stages: list != null ? List<String>.from(list) : null,
      position: j['position'] ?? 'bottomLeft',
      width: j['width'] ?? 260,
      height: j['height'] ?? 300,
      themeId: j['themeId'] ?? 'amber',
      fontId: j['fontId'] ?? 'mono',
      bgOpacity: (j['bgOpacity'] ?? 0.9).toDouble(),
      strokeWidth: (j['strokeWidth'] ?? 1.5).toDouble(),
    );
  }

  AxisSettings copyWith({
    String? rootName,
    List<String>? stages,
    String? position,
    int? width,
    int? height,
    String? themeId,
    String? fontId,
    double? bgOpacity,
    double? strokeWidth,
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
    );
  }
}

class SettingsService {
  static const _key = 'axis_settings_v4';
  static AxisSettings? _cached;

  static Future<AxisSettings> load() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      try {
        _cached = AxisSettings.fromJson(jsonDecode(json));
      } catch (_) {
        _cached = AxisSettings();
      }
    } else {
      _cached = AxisSettings();
    }
    return _cached!;
  }

  static Future<void> save(AxisSettings s) async {
    _cached = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }

  static void clearCache() => _cached = null;
}
