import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasPermission = false;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _checkPermission();
    final active = await FlutterOverlayWindow.isActive();
    setState(() => _isShowing = active);
  }

  Future<void> _checkPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    setState(() => _hasPermission = granted);
  }

  Future<void> _requestPermission() async {
    await FlutterOverlayWindow.requestPermission();
    await _checkPermission();
  }

  Future<void> _toggleOverlay() async {
    if (_isShowing) {
      await FlutterOverlayWindow.closeOverlay();
    } else {
      await FlutterOverlayWindow.showOverlay(
        height: 200,
        width: 220,
        alignment: OverlayAlignment.bottomLeft,
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'Parksy Axis',
        overlayContent: 'Stage Overlay Active',
      );
    }
    final active = await FlutterOverlayWindow.isActive();
    setState(() => _isShowing = active);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Parksy Axis',
              style: TextStyle(color: Colors.amber, fontSize: 24),
            ),
            const SizedBox(height: 24),
            if (!_hasPermission)
              ElevatedButton(
                onPressed: _requestPermission,
                child: const Text('권한 허용'),
              )
            else
              ElevatedButton(
                onPressed: _toggleOverlay,
                child: Text(_isShowing ? '오버레이 닫기' : '오버레이 시작'),
              ),
          ],
        ),
      ),
    );
  }
}
