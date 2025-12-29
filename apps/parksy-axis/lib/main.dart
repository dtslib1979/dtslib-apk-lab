import 'package:flutter/material.dart';
import 'app.dart';
import 'widgets/tree_view.dart';
import 'services/settings_service.dart';
import 'models/theme.dart';

/// Parksy Axis v5.0.0
/// 방송용 사고 단계 오버레이 - FSM 기반 상태 전이

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
  int _idx = 0;
  AxisSettings? _cfg;
  bool _init = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _cfg = await SettingsService.load();
    setState(() => _init = false);
  }

  /// FSM: s → (s+1) mod n
  void _next() {
    final n = _cfg?.stages.length ?? 5;
    setState(() => _idx = (_idx + 1) % n);
  }

  /// Direct jump: s → i
  void _jump(int i) => setState(() => _idx = i);

  @override
  Widget build(BuildContext context) {
    if (_init || _cfg == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(color: Colors.transparent),
      );
    }

    final t = AxisTheme.byId(_cfg!.themeId);
    final f = AxisFont.byId(_cfg!.fontId);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: TreeView(
          active: _idx,
          onTap: _next,
          onJump: _jump,
          root: _cfg!.rootName,
          items: _cfg!.stages,
          theme: t,
          font: f,
          opacity: _cfg!.bgOpacity,
          stroke: _cfg!.strokeWidth,
        ),
      ),
    );
  }
}
