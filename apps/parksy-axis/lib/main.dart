import 'package:flutter/material.dart';
import 'app.dart';
import 'widgets/tree_view.dart';
import 'services/settings_service.dart';

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
  AxisSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settings = await SettingsService.load();
    setState(() => _loading = false);
  }

  void _next() {
    final max = _settings?.stages.length ?? 5;
    setState(() => _stage = (_stage + 1) % max);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(color: Colors.transparent),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topLeft,
          child: TreeView(
            active: _stage,
            onTap: _next,
            rootName: _settings?.rootName ?? '[Idea]',
            stages: _settings?.stages ?? ['Capture', 'Note', 'Build', 'Test', 'Publish'],
          ),
        ),
      ),
    );
  }
}
