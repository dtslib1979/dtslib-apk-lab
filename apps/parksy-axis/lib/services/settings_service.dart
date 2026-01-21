import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// v7.3: path_provider 제거 - 오버레이 프로세스에서 platform channel 문제 해결

/// 설정 모델 - v7 스키마
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

  @override
  String toString() => 'AxisSettings(root: $rootName, stages: $stages, theme: $themeId)';
}

/// 템플릿 모델
class AxisTemplate {
  final String id;
  final String name;
  final bool isPreset;
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

/// v7.3: 파일 기반 설정 서비스 (하드코딩 경로 - 오버레이 호환)
class SettingsService {
  // 하드코딩된 경로 - path_provider 없이 오버레이에서도 동작
  static const _basePath = '/data/data/kr.parksy.axis/files';
  static const _fileName = 'axis_overlay_config.json';

  /// 오버레이용 설정 파일 경로 (동기)
  static File get _configFile => File('$_basePath/$_fileName');

  /// 오버레이용 설정 저장 (메인 앱에서 호출)
  static Future<void> saveForOverlay(AxisSettings s) async {
    try {
      final file = _configFile;

      // 디렉토리 생성 확인
      final dir = Directory(_basePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final json = jsonEncode(s.toJson());
      await file.writeAsString(json, flush: true);

      // 추가 sync 호출
      final raf = await file.open(mode: FileMode.append);
      await raf.flush();
      await raf.close();

      debugPrint('[SettingsService] saveForOverlay: $s');
      debugPrint('[SettingsService] saved to: ${file.path}');
    } catch (e) {
      debugPrint('[SettingsService] saveForOverlay ERROR: $e');
    }
  }

  /// 오버레이용 설정 로드 (오버레이에서 호출)
  static Future<AxisSettings> loadForOverlay() async {
    try {
      final file = _configFile;
      debugPrint('[SettingsService] loadForOverlay from: ${file.path}');

      if (await file.exists()) {
        final json = await file.readAsString();
        debugPrint('[SettingsService] loaded json: $json');
        final settings = AxisSettings.fromJson(jsonDecode(json));
        debugPrint('[SettingsService] parsed: $settings');
        return settings;
      } else {
        debugPrint('[SettingsService] file not found, using defaults');
      }
    } catch (e) {
      debugPrint('[SettingsService] loadForOverlay ERROR: $e');
    }
    return AxisSettings();
  }

  /// 오버레이 스케일만 저장 (핀치 줌 후)
  static Future<void> saveScale(double scale) async {
    try {
      final settings = await loadForOverlay();
      settings.overlayScale = scale;
      await saveForOverlay(settings);
    } catch (e) {
      debugPrint('[SettingsService] saveScale ERROR: $e');
    }
  }
}

/// 템플릿 서비스
class TemplateService {
  static const _templatesKey = 'axis_templates_v7';
  static const _selectedKey = 'axis_selected_v7';

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
  }

  /// 선택된 템플릿 ID 로드
  static Future<String> getSelectedId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_selectedKey) ?? 'default';
  }
}
