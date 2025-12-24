import 'package:flutter/material.dart';
import 'app.dart';
import 'widgets/tree_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AxisApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  int _stage = 0;

  void _next() {
    setState(() => _stage = (_stage + 1) % 5);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: TreeView(active: _stage, onTap: _next),
      ),
    );
  }
}
