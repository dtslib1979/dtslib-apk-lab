import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void main() {
  runApp(const ParksyAxisApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  runApp(const AxisOverlay());
}

class ParksyAxisApp extends StatelessWidget {
  const ParksyAxisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LauncherScreen(),
    );
  }
}

class LauncherScreen extends StatelessWidget {
  const LauncherScreen({super.key});

  Future<void> _showOverlay() async {
    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }
    await FlutterOverlayWindow.showOverlay(
      height: 200,
      width: 300,
      alignment: OverlayAlignment.bottomLeft,
      enableDrag: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    _showOverlay();
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Parksy Axis',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

// Placeholder - will be implemented in session 2
class AxisOverlay extends StatelessWidget {
  const AxisOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text('AXIS', style: TextStyle(color: Colors.amber)),
        ),
      ),
    );
  }
}
