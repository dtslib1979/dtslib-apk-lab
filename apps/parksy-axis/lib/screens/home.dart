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
  bool _hasPerm = false;
  bool _showing = false;
  AxisSettings? _s;

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
      _loadSettings();
    }
  }

  Future<void> _init() async {
    await _checkPerm();
    await _loadSettings();
    final active = await FlutterOverlayWindow.isActive();
    setState(() => _showing = active);
  }

  Future<void> _loadSettings() async {
    SettingsService.clearCache();
    _s = await SettingsService.load();
    if (mounted) setState(() {});
  }

  Future<void> _checkPerm() async {
    final ok = await FlutterOverlayWindow.isPermissionGranted();
    setState(() => _hasPerm = ok);
  }

  Future<void> _reqPerm() async {
    await FlutterOverlayWindow.requestPermission();
    await _checkPerm();
  }

  OverlayAlignment _align() {
    switch (_s?.position ?? 'bottomLeft') {
      case 'topLeft': return OverlayAlignment.topLeft;
      case 'topRight': return OverlayAlignment.topRight;
      case 'bottomRight': return OverlayAlignment.bottomRight;
      default: return OverlayAlignment.bottomLeft;
    }
  }

  Future<void> _toggle() async {
    if (_showing) {
      await FlutterOverlayWindow.closeOverlay();
    } else {
      await FlutterOverlayWindow.showOverlay(
        height: _s?.height ?? 300,
        width: _s?.width ?? 260,
        alignment: _align(),
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'Parksy Axis',
        overlayContent: 'Stage Overlay Active',
      );
    }
    final active = await FlutterOverlayWindow.isActive();
    setState(() => _showing = active);
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result == true) await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _s != null ? AxisTheme.byId(_s!.themeId) : AxisTheme.presets.first;
    final font = _s != null ? AxisFont.byId(_s!.fontId) : AxisFont.presets.first;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            // 앱 아이콘
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_tree_rounded,
                color: theme.accent,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Parksy Axis',
              style: TextStyle(
                color: theme.accent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: font.family,
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
                'v4.0.0 Pro',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const Spacer(flex: 1),
            // 미리보기
            if (_s != null)
              SizedBox(
                width: 200,
                height: 200,
                child: TreeView(
                  active: 0,
                  onTap: () {},
                  rootName: _s!.rootName,
                  stages: _s!.stages,
                  theme: theme,
                  font: font,
                  bgOpacity: _s!.bgOpacity,
                  strokeWidth: _s!.strokeWidth,
                ),
              ),
            const Spacer(flex: 1),
            // 버튼
            if (!_hasPerm)
              ElevatedButton.icon(
                onPressed: _reqPerm,
                icon: const Icon(Icons.security),
                label: const Text('권한 허용'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              )
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggle,
                    icon: Icon(_showing ? Icons.stop : Icons.play_arrow),
                    label: Text(_showing ? '오버레이 닫기' : '오버레이 시작'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showing ? Colors.red : theme.accent,
                      foregroundColor: _showing ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.palette),
                    label: const Text('커스터마이징'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.accent,
                      side: BorderSide(color: theme.accent, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
