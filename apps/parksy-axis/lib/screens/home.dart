/// Parksy Axis v11.1.0 - 홈 화면
/// 컴포넌트 기반 UI + 개선된 상태 관리

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' hide OverlayPosition;
import '../core/constants.dart';
import '../core/extensions.dart';
import '../services/settings_service.dart';
import '../models/settings.dart';
import '../models/theme.dart';
import '../widgets/tree_view.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _perm = false;
  bool _on = false;
  List<AxisTemplate> _templates = [];
  String _selectedId = 'default';
  AxisSettings _preview = const AxisSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPerm();
      _refreshOverlayState();
    }
  }

  /// _selectedId가 _templates에 존재하는지 검증, 없으면 'default'로 폴백
  void _validateSelectedId() {
    if (_templates.isEmpty) return;
    final exists = _templates.any((t) => t.id == _selectedId);
    if (!exists) {
      debugPrint('[Home] _validateSelectedId: "$_selectedId" not in templates, fallback to default');
      _selectedId = 'default';
      TemplateService.setSelectedId('default');
    }
  }

  /// resume 시 오버레이 상태만 갱신 (_preview 건드리지 않음)
  Future<void> _refreshOverlayState() async {
    _on = await FlutterOverlayWindow.isActive();
    _templates = await TemplateService.loadAllTemplates();
    _selectedId = await TemplateService.getSelectedId();
    _validateSelectedId();
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    await _checkPerm();
    _templates = await TemplateService.loadAllTemplates();
    _selectedId = await TemplateService.getSelectedId();
    _validateSelectedId();

    // 파일에 저장된 설정이 있으면 그걸 쓴다 (커스터마이징 유지)
    final saved = await SettingsService.loadForOverlay();
    final cfg = saved.valueOrNull;
    if (cfg != null && cfg.isValid) {
      _preview = cfg;
      debugPrint('[Home] init: loaded from config file: $_preview');
    } else {
      _updatePreview();
      debugPrint('[Home] init: no saved config, using template: $_preview');
    }

    _on = await FlutterOverlayWindow.isActive();
    if (mounted) setState(() {});
  }

  /// 템플릿 목록만 새로고침 (_preview 건드리지 않음)
  Future<void> _loadTemplates() async {
    _templates = await TemplateService.loadAllTemplates();
    _selectedId = await TemplateService.getSelectedId();
    _validateSelectedId();
    if (mounted) setState(() {});
  }

  /// 템플릿 선택 시에만 _preview를 템플릿 값으로 교체
  void _updatePreview() {
    final t = _templates.firstWhere(
      (e) => e.id == _selectedId,
      orElse: () => _templates.first,
    );
    _preview = t.settings;
  }

  Future<void> _checkPerm() async {
    _perm = await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) setState(() {});
  }

  Future<void> _reqPerm() async {
    await FlutterOverlayWindow.requestPermission();
    await _checkPerm();
  }

  OverlayAlignment _align() {
    return switch (_preview.position) {
      OverlayPosition.topLeft => OverlayAlignment.topLeft,
      OverlayPosition.topRight => OverlayAlignment.topRight,
      OverlayPosition.bottomRight => OverlayAlignment.bottomRight,
      OverlayPosition.bottomLeft => OverlayAlignment.bottomLeft,
    };
  }

  Future<void> _toggle() async {
    if (_on) {
      await FlutterOverlayWindow.closeOverlay();
      await 300.ms.delay;
    } else {
      debugPrint('[Home] toggle: saving settings for overlay: $_preview');

      // 저장 + 검증
      final result = await SettingsService.saveForOverlay(_preview);
      if (result.isFailure) {
        debugPrint('[Home] toggle: SAVE FAILED');
      }

      // 저장 후 다시 읽어서 검증
      final verify = await SettingsService.loadForOverlay();
      debugPrint('[Home] toggle: verify read-back: ${verify.valueOrNull}');

      await 300.ms.delay;

      await FlutterOverlayWindow.showOverlay(
        height: _preview.scaledHeight,
        width: _preview.scaledWidth,
        alignment: _align(),
        enableDrag: true,
        flag: OverlayFlag.focusPointer,
        overlayTitle: AppInfo.name,
        overlayContent: 'v${AppInfo.version}',
      );

      // 오버레이 엔진 초기화 대기 후 shareData로 설정 직접 전송 (3회 재시도)
      final jsonStr = jsonEncode(_preview.toJson());
      for (var i = 0; i < 3; i++) {
        await 500.ms.delay;
        await FlutterOverlayWindow.shareData(jsonStr);
        debugPrint('[Home] shareData sent #${i + 1}');
      }
    }
    _on = await FlutterOverlayWindow.isActive();
    setState(() {});
  }

  void _onTemplateChanged(String? id) async {
    if (id == null) return;
    _selectedId = id;
    await TemplateService.setSelectedId(id);
    _updatePreview();
    // 템플릿 변경 시 파일에도 저장 (오버레이 동기화)
    await SettingsService.saveForOverlay(_preview);
    debugPrint('[Home] template changed: $_selectedId → $_preview');
    setState(() {});
  }

  void _settings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(initial: _preview),
      ),
    );

    if (result != null) {
      final saved = result['settings'] as AxisSettings;
      final name = result['name'] as String?;

      debugPrint('[Home] settings result: name=$name');
      debugPrint('[Home] settings: $saved');

      if (name != null && name.isNotEmpty) {
        // 새 템플릿으로 저장
        final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
        final template = AxisTemplate(
          id: id,
          name: name,
          isPreset: false,
          settings: saved,
          createdAt: DateTime.now(),
        );
        await TemplateService.saveUserTemplate(template);
        _selectedId = id;
        await TemplateService.setSelectedId(id);
      }

      // v9: 설정 적용
      _preview = saved;

      // 오버레이용 설정 파일 저장
      await SettingsService.saveForOverlay(saved);
      debugPrint('[Home] settings saved for overlay: $_preview');

      // 새 템플릿 저장한 경우에만 템플릿 목록 새로고침
      if (name != null && name.isNotEmpty) {
        final savedId = _selectedId; // 방금 저장한 ID 보존
        await _loadTemplates();
        // _loadTemplates()가 _validateSelectedId()로 폴백했을 수 있으므로 복원
        if (_templates.any((t) => t.id == savedId)) {
          _selectedId = savedId;
        }
        _preview = saved; // 복원
      }

      setState(() {});
    }
  }

  void _deleteTemplate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('템플릿 삭제', style: TextStyle(color: Colors.white)),
        content: const Text('이 템플릿을 삭제할까요?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await TemplateService.deleteUserTemplate(id);
      if (_selectedId == id) {
        _selectedId = 'default';
        await TemplateService.setSelectedId('default');
      }
      await _loadTemplates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AxisTheme.byId(_preview.themeId);
    final f = AxisFont.byId(_preview.fontId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // 헤더
            _Header(theme: t, font: f),
            const SizedBox(height: 24),

            // 템플릿 선택
            _TemplateSelector(
              templates: _templates,
              selectedId: _selectedId,
              theme: t,
              onChanged: _onTemplateChanged,
              onDelete: _deleteTemplate,
            ),
            const Spacer(),

            // 미리보기
            _Preview(
              preview: _preview,
              theme: t,
              font: f,
            ),
            const Spacer(),

            // 버튼
            _ActionButtons(
              hasPermission: _perm,
              isActive: _on,
              theme: t,
              onRequestPermission: _reqPerm,
              onToggle: _toggle,
              onSettings: _settings,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// 헤더 위젯
class _Header extends StatelessWidget {
  final AxisTheme theme;
  final AxisFont font;

  const _Header({required this.theme, required this.font});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => theme.accentGradient.createShader(bounds),
          child: Text(
            AppInfo.name,
            style: font.style(
              size: UIDefaults.fontSizeXLarge,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'v${AppInfo.version} Ultimate',
            style: TextStyle(color: theme.dim, fontSize: UIDefaults.fontSizeSmall),
          ),
        ),
      ],
    );
  }
}

/// 템플릿 선택기 위젯
class _TemplateSelector extends StatelessWidget {
  final List<AxisTemplate> templates;
  final String selectedId;
  final AxisTheme theme;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onDelete;

  const _TemplateSelector({
    required this.templates,
    required this.selectedId,
    required this.theme,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 안전장치: selectedId가 templates에 없으면 첫 번째 항목으로 폴백
    final safeId = templates.any((t) => t.id == selectedId)
        ? selectedId
        : (templates.isNotEmpty ? templates.first.id : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '템플릿 선택',
            style: TextStyle(
              color: theme.accent,
              fontSize: UIDefaults.fontSizeMedium,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.accent.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeId,
                isExpanded: true,
                dropdownColor: Colors.grey[850],
                style: const TextStyle(color: Colors.white),
                items: templates.map((tpl) {
                  return DropdownMenuItem(
                    value: tpl.id,
                    child: Row(
                      children: [
                        Icon(
                          tpl.isPreset ? Icons.star : Icons.save,
                          color: tpl.isPreset ? Colors.amber : theme.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(tpl.name)),
                        if (!tpl.isPreset)
                          GestureDetector(
                            onTap: () => onDelete(tpl.id),
                            child: const Icon(Icons.close, color: Colors.red, size: 18),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 미리보기 위젯
class _Preview extends StatelessWidget {
  final AxisSettings preview;
  final AxisTheme theme;
  final AxisFont font;

  const _Preview({
    required this.preview,
    required this.theme,
    required this.font,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.glow,
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TreeView(
        active: 0,
        onTap: () {},
        root: preview.rootName,
        items: preview.stages,
        theme: theme,
        font: font,
        opacity: preview.bgOpacity,
        stroke: preview.strokeWidth,
        enableAnimation: false,
      ),
    );
  }
}

/// 액션 버튼 위젯
class _ActionButtons extends StatelessWidget {
  final bool hasPermission;
  final bool isActive;
  final AxisTheme theme;
  final VoidCallback onRequestPermission;
  final VoidCallback onToggle;
  final VoidCallback onSettings;

  const _ActionButtons({
    required this.hasPermission,
    required this.isActive,
    required this.theme,
    required this.onRequestPermission,
    required this.onToggle,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasPermission) {
      return _ActionButton(
        text: '권한 허용',
        icon: Icons.security,
        color: theme.accent,
        onPressed: onRequestPermission,
      );
    }

    return Column(
      children: [
        _ActionButton(
          text: isActive ? '오버레이 닫기' : '오버레이 시작',
          icon: isActive ? Icons.stop : Icons.play_arrow,
          color: isActive ? Colors.red : theme.accent,
          onPressed: onToggle,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.edit),
          label: const Text('커스터마이징'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.accent,
            side: BorderSide(color: theme.accent, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          ),
        ),
      ],
    );
  }
}

/// 액션 버튼 위젯
class _ActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: color == Colors.red ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
    );
  }
}
