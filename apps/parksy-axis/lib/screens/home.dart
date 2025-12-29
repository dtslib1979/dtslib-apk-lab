import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/settings_service.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasPermission = false;
  bool _isShowing = false;
  AxisSettings? _settings;

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
      _checkPermission();
      _loadSettings();
    }
  }

  Future<void> _init() async {
    await _checkPermission();
    await _loadSettings();
    final active = await FlutterOverlayWindow.isActive();
    setState(() => _isShowing = active);
  }

  Future<void> _loadSettings() async {
    SettingsService.clearCache();
    _settings = await SettingsService.load();
    if (mounted) setState(() {});
  }

  Future<void> _checkPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    setState(() => _hasPermission = granted);
  }

  Future<void> _requestPermission() async {
    await FlutterOverlayWindow.requestPermission();
    await _checkPermission();
  }

  OverlayAlignment _getAlignment() {
    switch (_settings?.position ?? 'bottomLeft') {
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

  Future<void> _toggleOverlay() async {
    if (_isShowing) {
      await FlutterOverlayWindow.closeOverlay();
    } else {
      await FlutterOverlayWindow.showOverlay(
        height: _settings?.height ?? 300,
        width: _settings?.width ?? 260,
        alignment: _getAlignment(),
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'Parksy Axis',
        overlayContent: 'Stage Overlay Active',
      );
    }
    final active = await FlutterOverlayWindow.isActive();
    setState(() => _isShowing = active);
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result == true) {
      await _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // 앱 아이콘
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_tree_rounded,
                color: Colors.amber,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            // 타이틀
            const Text(
              'Parksy Axis',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            // 버전 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Text(
                'v3.0.0',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(flex: 2),
            // 버튼 영역
            Center(
              child: !_hasPermission
                  ? ElevatedButton.icon(
                      onPressed: _requestPermission,
                      icon: const Icon(Icons.security),
                      label: const Text('권한 허용'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _toggleOverlay,
                          icon: Icon(_isShowing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                          label: Text(_isShowing ? '오버레이 닫기' : '오버레이 시작'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isShowing ? Colors.red : Colors.amber,
                            foregroundColor: _isShowing ? Colors.white : Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('트리 편집'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber,
                            side: const BorderSide(color: Colors.amber, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
