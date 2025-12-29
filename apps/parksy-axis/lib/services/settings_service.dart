import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// S/M/L 프리셋 크기 (화면 비율 기준)
enum SizePreset {
  S, // 28~32%
  M, // 38~45%
  L, // 50~60%
}

extension SizePresetExt on SizePreset {
  String get label => name;

  /// 화면 너비 대비 비율
  double get widthRatio {
    switch (this) {
      case SizePreset.S: return 0.30;
      case SizePreset.M: return 0.42;
      case SizePreset.L: return 0.55;
    }
  }

  /// 다음 프리셋 (순환)
  SizePreset get next {
    switch (this) {
      case SizePreset.S: return SizePreset.M;
      case SizePreset.M: return SizePreset.L;
      case SizePreset.L: return SizePreset.S;
    }
  }

  static SizePreset fromString(String? s) {
    switch (s) {
      case 'M': return SizePreset.M;
      case 'L': return SizePreset.L;
      default: return SizePreset.S;
    }
  }
}

class AxisSettings {
  String rootName;
  List<String> stages;
  String position; // bottomLeft, bottomRight, topLeft, topRight
  SizePreset sizePreset;

  AxisSettings({
    this.rootName = '[Idea]',
    List<String>? stages,
    this.position = 'bottomLeft',
    this.sizePreset = SizePreset.S,
  }) : stages = stages ?? ['Capture', 'Note', 'Build', 'Test', 'Publish'];

  Map<String, dynamic> toJson() => {
        'rootName': rootName,
        'stages': stages,
        'position': position,
        'sizePreset': sizePreset.label,
      };

  factory AxisSettings.fromJson(Map<String, dynamic> json) {
    final stagesList = json['stages'] as List?;
    return AxisSettings(
      rootName: json['rootName'] ?? '[Idea]',
      stages: (stagesList != null && stagesList.isNotEmpty)
          ? List<String>.from(stagesList)
          : null,
      position: json['position'] ?? 'bottomLeft',
      sizePreset: SizePresetExt.fromString(json['sizePreset']),
    );
  }

  /// 화면 크기 기준 오버레이 너비 계산
  int getWidth(double screenWidth) {
    return (screenWidth * sizePreset.widthRatio).toInt().clamp(150, 500);
  }

  /// 높이는 내용에 맞게 자동 (최대치만 제한)
  int getHeight(double screenHeight) {
    return (screenHeight * 0.4).toInt().clamp(100, 400);
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

  /// 프리셋만 빠르게 저장 (오버레이에서 사용)
  static Future<void> saveSizePreset(SizePreset preset) async {
    final settings = await load();
    settings.sizePreset = preset;
    await save(settings);
  }

  static void clearCache() {
    _cached = null;
  }
}
