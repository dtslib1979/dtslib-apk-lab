import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'state.dart';

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
    final ok = await FlutterOverlayWindow.isPermissionGranted();
    if (!ok) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }
    await FlutterOverlayWindow.showOverlay(
      height: 180,
      width: 280,
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
        child: Text('Parksy Axis', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}

class AxisOverlay extends StatefulWidget {
  const AxisOverlay({super.key});

  @override
  State<AxisOverlay> createState() => _AxisOverlayState();
}

class _AxisOverlayState extends State<AxisOverlay> {
  final _state = AxisState();

  void _onTap() => setState(() => _state.next());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GestureDetector(
        onTap: _onTap,
        child: Container(
          color: Colors.black.withOpacity(0.85),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '[Idea]',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              ...List.generate(5, (i) => _buildNode(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(int i) {
    final active = _state.isActive(i);
    final prefix = i < 4 ? '├─' : '└─';
    final marker = active ? '● ' : '  ';
    final label = AxisState.labels[i];

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Text(
        '$prefix $marker$label',
        style: TextStyle(
          color: active ? Colors.amber : Colors.grey,
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
