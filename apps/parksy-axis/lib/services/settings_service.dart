import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정 모델 - v6 스키마
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
        'overlayScale': overlayScale,
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
        overlayScale: (j['overlayScale'] ?? 1.0).toDouble(),
      );

  AxisSettings copy() => AxisSettings(
        rootName: rootName,
        stages: List.from(stages),
        position: position,
        width: width,
        height: height,
        themeId: themeId,
        fontId: fontId,
        bgOpacity: bgOpacity,
        strokeWidth: strokeWidth,
        overlayScale: overlayScale,
      );
}

/// 템플릿 모델
class AxisTemplate {
  final String id;
  final String name;
  final bool isPreset; // true = 기본 프리셋, false = 사용자 저장
  final AxisSettings settings;

  AxisTemplate({
    required this.id,
    required this.name,
    required this.isPreset,
    required this.settings,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isPreset': isPreset,
        'settings': settings.toJson(),
      };

  factory AxisTemplate.fromJson(Map<String, dynamic> j) => AxisTemplate(
        id: j['id'],
        name: j['name'],
        isPreset: j['isPreset'] ?? false,
        settings: AxisSettings.fromJson(j['settings']),
      );
}

/// 템플릿 서비스
class TemplateService {
  static const _templatesKey = 'axis_templates_v6';
  static const _selectedKey = 'axis_selected_v6';
  static const _activeKey = 'axis_active_v6'; // 오버레이용 활성 설정

  /// 기본 프리셋
  static List<AxisTemplate> get presets => [
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
            rootName: '[LIVE]',
            stages: ['대기', '인트로', '본방', '마무리', '종료'],
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
            rootName: '[회의]',
            stages: ['안건', '토론', '결론', '액션'],
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
            rootName: '[DEV]',
            stages: ['Plan', 'Code', 'Test', 'Deploy'],
            themeId: 'lime',
            fontId: 'mono',
          ),
        ),
      ];

  /// 사용자 템플릿 로드
  static Future<List<AxisTemplate>> loadUserTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_templatesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => AxisTemplate.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 사용자 템플릿 저장
  static Future<void> saveUserTemplate(AxisTemplate t) async {
    final templates = await loadUserTemplates();
    // 같은 ID 있으면 교체
    final idx = templates.indexWhere((e) => e.id == t.id);
    if (idx >= 0) {
      templates[idx] = t;
    } else {
      templates.add(t);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _templatesKey,
      jsonEncode(templates.map((e) => e.toJson()).toList()),
    );
    await prefs.reload();
  }

  /// 사용자 템플릿 삭제
  static Future<void> deleteUserTemplate(String id) async {
    final templates = await loadUserTemplates();
    templates.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _templatesKey,
      jsonEncode(templates.map((e) => e.toJson()).toList()),
    );
    await prefs.reload();
  }

  /// 모든 템플릿 (프리셋 + 사용자)
  static Future<List<AxisTemplate>> loadAllTemplates() async {
    final user = await loadUserTemplates();
    return [...presets, ...user];
  }

  /// 선택된 템플릿 ID 저장
  static Future<void> setSelectedId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, id);
    await prefs.reload();
  }

  /// 선택된 템플릿 ID 로드
  static Future<String> getSelectedId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_selectedKey) ?? 'default';
  }

  /// 활성 설정 저장 (오버레이 시작 직전 호출)
  static Future<void> setActiveSettings(AxisSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, jsonEncode(s.toJson()));
    await prefs.reload();
    // 추가 동기화
    await Future.delayed(const Duration(milliseconds: 100));
    await prefs.reload();
  }

  /// 활성 설정 로드 (오버레이에서 호출)
  static Future<AxisSettings> getActiveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_activeKey);
    if (raw != null) {
      try {
        return AxisSettings.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    return AxisSettings();
  }
}

/// 하위 호환성을 위한 기존 SettingsService (deprecated)
class SettingsService {
  static const _key = 'axis_v5';
  static AxisSettings? _cache;

  static Future<AxisSettings> load() async {
    if (_cache != null) return _cache!;
    return loadFresh();
  }

  static Future<AxisSettings> loadFresh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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
    await prefs.reload();
  }

  static void clear() => _cache = null;
}
