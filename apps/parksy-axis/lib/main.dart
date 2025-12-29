import 'package:flutter/material.dart';
import 'app.dart';
import 'widgets/tree_view.dart';
import 'services/settings_service.dart';
import 'models/theme.dart';

// v4.0.0 Pro Edition - Force rebuild trigger

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
  AxisSettings? _s;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _s = await SettingsService.load();
    setState(() => _loading = false);
  }

  void _next() {
    final max = _s?.stages.length ?? 5;
    setState(() => _stage = (_stage + 1) % max);
  }

  void _jump(int i) => setState(() => _stage = i);

  @override
  Widget build(BuildContext context) {
    if (_loading || _s == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(color: Colors.transparent),
      );
    }

    final theme = AxisTheme.byId(_s!.themeId);
    final font = AxisFont.byId(_s!.fontId);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: TreeView(
          active: _stage,
          onTap: _next,
          onStageTap: _jump,
          rootName: _s!.rootName,
          stages: _s!.stages,
          theme: theme,
          font: font,
          bgOpacity: _s!.bgOpacity,
          strokeWidth: _s!.strokeWidth,
        ),
      ),
    );
  }
}
