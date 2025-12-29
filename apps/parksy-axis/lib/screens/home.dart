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
      // 화면 크기 기반 오버레이 크기 계산
      final screen = MediaQuery.of(context).size;
      final width = _settings?.getWidth(screen.width) ?? 220;
      final height = _settings?.getHeight(screen.height) ?? 200;

      await FlutterOverlayWindow.showOverlay(
        height: height,
        width: width,
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
    final sizeLabel = _settings?.sizePreset.label ?? 'S';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Text(
              'Parksy Axis',
              style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'v2.3.0',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Size: $sizeLabel',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const Spacer(),
            if (!_hasPermission)
              ElevatedButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.security),
                label: const Text('권한 허용'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _toggleOverlay,
                icon: Icon(_isShowing ? Icons.stop : Icons.play_arrow),
                label: Text(_isShowing ? '오버레이 닫기' : '오버레이 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isShowing ? Colors.red : Colors.amber,
                  foregroundColor: _isShowing ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings, color: Colors.grey, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
