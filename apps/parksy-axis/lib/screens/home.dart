import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/settings_service.dart';
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
  AxisSettings? _preview;

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
      _loadTemplates();
    }
  }

  Future<void> _init() async {
    await _checkPerm();
    await _loadTemplates();
    _on = await FlutterOverlayWindow.isActive();
    if (mounted) setState(() {});
  }

  Future<void> _loadTemplates() async {
    _templates = await TemplateService.loadAllTemplates();
    _selectedId = await TemplateService.getSelectedId();
    _updatePreview();
    if (mounted) setState(() {});
  }

  void _updatePreview() {
    final t = _templates.firstWhere(
      (e) => e.id == _selectedId,
      orElse: () => _templates.first,
    );
    _preview = t.settings.copy();
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
    switch (_preview?.position ?? 'bottomLeft') {
      case 'topLeft':
        return OverlayAlignment.topLeft;
      case 'topRight':
        return OverlayAlignment.topRight;
      case 'bottomRight':
        return OverlayAlignment.bottomRight;
      default:
        return OverlayAlignment.bottomLeft;
    }
  }

  Future<void> _toggle() async {
    if (_on) {
      await FlutterOverlayWindow.closeOverlay();
      // v7.2: 오버레이 종료 후 딜레이 (재시작 문제 수정)
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      if (_preview != null) {
        // v7: 파일로 설정 저장 (프로세스 간 동기화 보장)
        debugPrint('[Home] saving settings for overlay: $_preview');
        await SettingsService.saveForOverlay(_preview!);

        // 파일 쓰기 완료 대기
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final w = (_preview?.width ?? 260) * (_preview?.overlayScale ?? 1.0);
      final h = (_preview?.height ?? 300) * (_preview?.overlayScale ?? 1.0);

      await FlutterOverlayWindow.showOverlay(
        height: h.toInt(),
        width: w.toInt(),
        alignment: _align(),
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'Parksy Axis',
        overlayContent: 'v7.3',
      );
    }
    _on = await FlutterOverlayWindow.isActive();
    setState(() {});
  }

  void _onTemplateChanged(String? id) async {
    if (id == null) return;
    _selectedId = id;
    await TemplateService.setSelectedId(id);
    _updatePreview();
    setState(() {});
  }

  void _settings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          initial: _preview?.copy() ?? AxisSettings(),
        ),
      ),
    );
    
    if (result != null) {
      final saved = result['settings'] as AxisSettings;
      final name = result['name'] as String?;
      final applyNow = result['applyNow'] as bool? ?? false;

      debugPrint('[Home] settings result: name=$name, applyNow=$applyNow');
      debugPrint('[Home] settings: $saved');

      if (name != null && name.isNotEmpty) {
        // 새 템플릿으로 저장
        final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
        final template = AxisTemplate(
          id: id,
          name: name,
          isPreset: false,
          settings: saved,
        );
        await TemplateService.saveUserTemplate(template);
        _selectedId = id;
        await TemplateService.setSelectedId(id);
      }
      
      // v7.2: 설정 적용 - _loadTemplates() 호출하지 않음 (버그 수정)
      // _loadTemplates()가 _updatePreview()를 호출해서 _preview를 템플릿 원본으로 덮어쓰는 버그 있었음
      _preview = saved.copy();

      // 오버레이용 설정 파일 저장
      await SettingsService.saveForOverlay(saved);
      debugPrint('[Home] settings saved for overlay: $_preview');

      // 새 템플릿 저장한 경우에만 템플릿 목록 새로고침
      if (name != null && name.isNotEmpty) {
        await _loadTemplates();
        // 중요: _loadTemplates() 후 _preview 복원 (덮어쓰기 방지)
        _preview = saved.copy();
      }
    }
  }

  void _deleteTemplate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('템플릿 삭제'),
        content: const Text('이 템플릿을 삭제할까요?'),
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
    final t = _preview != null
        ? AxisTheme.byId(_preview!.themeId)
        : AxisTheme.presets.first;
    final f = _preview != null
        ? AxisFont.byId(_preview!.fontId)
        : AxisFont.presets.first;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // 헤더
            Text(
              'Parksy Axis',
              style: TextStyle(
                color: t.accent,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: f.family,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'v7.3',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // 템플릿 선택
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '템플릿 선택',
                    style: TextStyle(
                      color: t.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.accent.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedId,
                        isExpanded: true,
                        dropdownColor: Colors.grey[850],
                        style: const TextStyle(color: Colors.white),
                        items: _templates.map((tpl) {
                          return DropdownMenuItem(
                            value: tpl.id,
                            child: Row(
                              children: [
                                Icon(
                                  tpl.isPreset ? Icons.star : Icons.save,
                                  color: tpl.isPreset ? Colors.amber : t.accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(tpl.name)),
                                if (!tpl.isPreset)
                                  GestureDetector(
                                    onTap: () => _deleteTemplate(tpl.id),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _onTemplateChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // 미리보기
            if (_preview != null)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: t.accent.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: TreeView(
                  active: 0,
                  onTap: () {},
                  root: _preview!.rootName,
                  items: _preview!.stages,
                  theme: t,
                  font: f,
                  opacity: _preview!.bgOpacity,
                  stroke: _preview!.strokeWidth,
                ),
              ),
            const Spacer(),

            // 버튼
            if (!_perm)
              Center(child: _btn('권한 허용', Icons.security, t.accent, _reqPerm))
            else
              Center(
                child: Column(
                  children: [
                    _btn(
                      _on ? '오버레이 닫기' : '오버레이 시작',
                      _on ? Icons.stop : Icons.play_arrow,
                      _on ? Colors.red : t.accent,
                      _toggle,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _settings,
                      icon: const Icon(Icons.edit),
                      label: const Text('커스터마이징'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.accent,
                        side: BorderSide(color: t.accent, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _btn(String txt, IconData ic, Color c, VoidCallback fn) {
    return ElevatedButton.icon(
      onPressed: fn,
      icon: Icon(ic),
      label: Text(txt),
      style: ElevatedButton.styleFrom(
        backgroundColor: c,
        foregroundColor: c == Colors.red ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
    );
  }
}
