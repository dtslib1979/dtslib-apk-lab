/// Parksy Axis v9.0.0 - 설정 서비스
/// Result 패턴 + 파일 기반 동기화

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/settings.dart';

/// 결과 타입 - 성공/실패 처리
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  T getOrDefault(T defaultValue) => valueOrNull ?? defaultValue;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(String error) onFailure,
  }) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(error: final e) => onFailure(e),
    };
  }
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final String error;
  const Failure(this.error);
}

/// v9.0.0: 파일 기반 설정 서비스 (하드코딩 경로 - 오버레이 호환)
class SettingsService {
  static const _basePath = '/data/data/${AppInfo.packageName}/files';
  static const _fileName = StorageKeys.configFileName;

  static File get _configFile => File('$_basePath/$_fileName');

  static const _prefsBackupKey = 'axis_overlay_config_backup';

  /// 오버레이용 설정 저장 (메인 앱에서 호출)
  /// 파일 + SharedPreferences 이중 저장
  static Future<Result<void>> saveForOverlay(AxisSettings settings) async {
    try {
      final json = jsonEncode(settings.toJson());

      // 1) 파일 저장
      final file = _configFile;
      final dir = Directory(_basePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsString(json, flush: true);

      // 추가 sync 호출
      final raf = await file.open(mode: FileMode.append);
      await raf.flush();
      await raf.close();

      // 2) SharedPreferences 백업 (오버레이에서 파일 못 읽을 때 보험)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsBackupKey, json);
      } catch (e) {
        debugPrint('[SettingsService] prefs backup failed (non-fatal): $e');
      }

      debugPrint('[SettingsService] saveForOverlay OK: $settings');
      return const Success(null);
    } catch (e) {
      debugPrint('[SettingsService] saveForOverlay ERROR: $e');
      return Failure('저장 실패: $e');
    }
  }

  /// 오버레이용 설정 로드 (오버레이에서 호출)
  /// 파일 우선, 실패 시 SharedPreferences 폴백
  static Future<Result<AxisSettings>> loadForOverlay() async {
    try {
      final file = _configFile;
      debugPrint('[SettingsService] loadForOverlay from: ${file.path}');

      // 1) 파일에서 로드 시도
      if (await file.exists()) {
        final json = await file.readAsString();
        if (json.isNotEmpty) {
          debugPrint('[SettingsService] loaded from file: $json');
          final settings = AxisSettings.fromJson(jsonDecode(json));
          debugPrint('[SettingsService] parsed: $settings');
          return Success(settings);
        }
      }

      // 2) 파일 없거나 비어있으면 SharedPreferences 폴백
      debugPrint('[SettingsService] file miss, trying prefs backup');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final backup = prefs.getString(_prefsBackupKey);
      if (backup != null && backup.isNotEmpty) {
        debugPrint('[SettingsService] loaded from prefs backup: $backup');
        final settings = AxisSettings.fromJson(jsonDecode(backup));
        return Success(settings);
      }

      debugPrint('[SettingsService] no saved config anywhere, using defaults');
      return const Success(AxisSettings());
    } catch (e) {
      debugPrint('[SettingsService] loadForOverlay ERROR: $e');
      return Failure('로드 실패: $e');
    }
  }

  /// 오버레이 스케일만 저장 (핀치 줌 후)
  static Future<Result<void>> saveScale(double scale) async {
    try {
      final result = await loadForOverlay();
      final settings = result.getOrDefault(const AxisSettings());
      final updated = settings.copyWith(overlayScale: scale);
      return saveForOverlay(updated);
    } catch (e) {
      debugPrint('[SettingsService] saveScale ERROR: $e');
      return Failure('스케일 저장 실패: $e');
    }
  }
}

/// 템플릿 서비스
class TemplateService {
  static const _templatesKey = StorageKeys.templatesKey;
  static const _selectedKey = StorageKeys.selectedTemplateKey;

  /// 기본 프리셋
  static List<AxisTemplate> get presets => PresetTemplates.all;

  /// 사용자 템플릿 로드
  static Future<Result<List<AxisTemplate>>> loadUserTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_templatesKey);
      if (raw == null) return const Success([]);

      final list = jsonDecode(raw) as List;
      final templates = list.map((e) => AxisTemplate.fromJson(e)).toList();
      return Success(templates);
    } catch (e) {
      debugPrint('[TemplateService] loadUserTemplates ERROR: $e');
      return Failure('템플릿 로드 실패: $e');
    }
  }

  /// 사용자 템플릿 저장
  static Future<Result<void>> saveUserTemplate(AxisTemplate template) async {
    try {
      final result = await loadUserTemplates();
      final templates = result.getOrDefault([]);

      final idx = templates.indexWhere((e) => e.id == template.id);
      if (idx >= 0) {
        templates[idx] = template;
      } else {
        templates.add(template);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _templatesKey,
        jsonEncode(templates.map((e) => e.toJson()).toList()),
      );
      return const Success(null);
    } catch (e) {
      debugPrint('[TemplateService] saveUserTemplate ERROR: $e');
      return Failure('템플릿 저장 실패: $e');
    }
  }

  /// 사용자 템플릿 삭제
  static Future<Result<void>> deleteUserTemplate(String id) async {
    try {
      final result = await loadUserTemplates();
      final templates = result.getOrDefault([]);
      templates.removeWhere((e) => e.id == id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _templatesKey,
        jsonEncode(templates.map((e) => e.toJson()).toList()),
      );
      return const Success(null);
    } catch (e) {
      debugPrint('[TemplateService] deleteUserTemplate ERROR: $e');
      return Failure('템플릿 삭제 실패: $e');
    }
  }

  /// 모든 템플릿 (프리셋 + 사용자)
  static Future<List<AxisTemplate>> loadAllTemplates() async {
    final result = await loadUserTemplates();
    final user = result.getOrDefault([]);
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
