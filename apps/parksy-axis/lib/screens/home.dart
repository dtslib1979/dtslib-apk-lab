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
  AxisSettings? _cfg;

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
      _reload();
    }
  }

  Future<void> _init() async {
    await _checkPerm();
    await _reload();
    _on = await FlutterOverlayWindow.isActive();
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    SettingsService.clear();
    _cfg = await SettingsService.load();
    if (mounted) setState(() {});
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
    switch (_cfg?.position ?? 'bottomLeft') {
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
    } else {
      await FlutterOverlayWindow.showOverlay(
        height: _cfg?.height ?? 300,
        width: _cfg?.width ?? 260,
        alignment: _align(),
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'Parksy Axis',
        overlayContent: 'v5.1.0',
      );
    }
    _on = await FlutterOverlayWindow.isActive();
    setState(() {});
  }

  void _settings() async {
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (ok == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = _cfg != null ? AxisTheme.byId(_cfg!.themeId) : AxisTheme.presets.first;
    final f = _cfg != null ? AxisFont.byId(_cfg!.fontId) : AxisFont.presets.first;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            // 아이콘
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_tree_rounded, color: t.accent, size: 64),
            ),
            const SizedBox(height: 20),
            Text(
              'Parksy Axis',
              style: TextStyle(
                color: t.accent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: f.family,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'v5.1.0',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const Spacer(),
            // 미리보기
            if (_cfg != null)
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
                  root: _cfg!.rootName,
                  items: _cfg!.stages,
                  theme: t,
                  font: f,
                  opacity: _cfg!.bgOpacity,
                  stroke: _cfg!.strokeWidth,
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
                      icon: const Icon(Icons.palette),
                      label: const Text('커스터마이징'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.accent,
                        side: BorderSide(color: t.accent, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(flex: 2),
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
