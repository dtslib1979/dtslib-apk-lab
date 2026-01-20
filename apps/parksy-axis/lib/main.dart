import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'app.dart';
import 'widgets/tree_view.dart';
import 'services/settings_service.dart';
import 'models/theme.dart';

/// Parksy Axis v5.3.0
/// 방송용 사고 단계 오버레이 - FSM 기반 상태 전이
///
/// v5.3.0: 오버레이 설정 동기화 버그 수정
///   - loadFresh()로 항상 최신 설정 로드
///   - SharedPreferences.reload() 추가

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
  double _baseScale = 1.0;
  double _currentScale = 1.0;
  int _currentW = 260;
  int _currentH = 300;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 오버레이는 항상 최신 설정을 SharedPreferences에서 직접 로드
    _cfg = await SettingsService.loadFresh();
    _currentScale = _cfg!.overlayScale;
    _currentW = (_cfg!.width * _currentScale).toInt();
    _currentH = (_cfg!.height * _currentScale).toInt();
    setState(() => _init = false);
  }

  /// FSM: s → (s+1) mod n
  void _next() {
    final n = _cfg?.stages.length ?? 5;
    setState(() => _idx = (_idx + 1) % n);
  }

  /// Direct jump: s → i
  void _jump(int i) => setState(() => _idx = i);

  /// 핀치 줌 시작
  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _currentScale;
  }

  /// 핀치 줌 처리 (창 크기 조절 방식)
  void _onScaleUpdate(ScaleUpdateDetails d) {
    final target = (_baseScale * d.scale).clamp(0.5, 2.5);
    _currentScale = _currentScale + (target - _currentScale) * 0.3;
    _currentW = (_cfg!.width * _currentScale).toInt();
    _currentH = (_cfg!.height * _currentScale).toInt();
    FlutterOverlayWindow.resizeOverlay(_currentW, _currentH, true);
    setState(() {});
  }

  /// 핀치 줌 종료 시 저장
  Future<void> _onScaleEnd(ScaleEndDetails d) async {
    _cfg!.overlayScale = _currentScale;
    await SettingsService.save(_cfg!);
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
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: SizedBox(
            width: _currentW.toDouble(),
            height: _currentH.toDouble(),
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
