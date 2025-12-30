import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'app.dart';
import 'widgets/tree_view.dart';
import 'services/settings_service.dart';
import 'models/theme.dart';

/// Parksy Axis v5.1.0
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
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _cfg = await SettingsService.load();
    _scale = _cfg?.overlayScale ?? 1.0;
    setState(() => _init = false);
  }

  /// FSM: s → (s+1) mod n
  void _next() {
    final n = _cfg?.stages.length ?? 5;
    setState(() => _idx = (_idx + 1) % n);
  }

  /// Direct jump: s → i
  void _jump(int i) => setState(() => _idx = i);

  /// 핀치 줌 처리
  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale = (_scale * d.scale).clamp(0.5, 2.0);
    });
  }

  /// 핀치 줌 종료 시 저장 및 리사이즈
  Future<void> _onScaleEnd(ScaleEndDetails d) async {
    if (_cfg != null) {
      _cfg!.overlayScale = _scale;
      await SettingsService.save(_cfg!);
      final w = (_cfg!.width * _scale).toInt();
      final h = (_cfg!.height * _scale).toInt();
      await FlutterOverlayWindow.resizeOverlay(w, h, true);
    }
  }

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
        child: GestureDetector(
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: Transform.scale(
            scale: _scale,
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
        ),
      ),
    );
  }
}
