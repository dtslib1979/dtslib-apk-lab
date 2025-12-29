import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AxisSettings {
  String rootName;
  List<String> stages;
  String position; // bottomLeft, bottomRight, topLeft, topRight
  int width;
  int height;

  AxisSettings({
    this.rootName = '[Idea]',
    List<String>? stages,
    this.position = 'bottomLeft',
    this.width = 220,
    this.height = 200,
  }) : stages = stages ?? ['Capture', 'Note', 'Build', 'Test', 'Publish'];

  Map<String, dynamic> toJson() => {
        'rootName': rootName,
        'stages': stages,
        'position': position,
        'width': width,
        'height': height,
      };

  factory AxisSettings.fromJson(Map<String, dynamic> json) {
    final stagesList = json['stages'] as List?;
    final stages = stagesList != null && stagesList.isNotEmpty
        ? List<String>.from(stagesList)
        : null; // null이면 생성자 기본값 사용
    return AxisSettings(
      rootName: json['rootName'] ?? '[Idea]',
      stages: stages,
      position: json['position'] ?? 'bottomLeft',
      width: json['width'] ?? 220,
      height: json['height'] ?? 200,
    );
  }
}

class SettingsService {
  static const _key = 'axis_settings';
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

  static Future<void> save(AxisSettings settings) async {
    _cached = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  static void clearCache() {
    _cached = null;
  }
}
