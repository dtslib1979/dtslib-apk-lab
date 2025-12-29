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

  /// 탭 → 다음 스테이지
  void _next() {
    final max = _settings?.stages.length ?? 5;
    setState(() => _stage = (_stage + 1) % max);
  }

  /// 스테이지 직접 점프
  void _jumpTo(int index) {
    setState(() => _stage = index);
  }

  /// 더블탭 → S/M/L 크기 순환
  Future<void> _cycleSize() async {
    if (_settings == null) return;
    final next = _settings!.sizePreset.next;
    _settings!.sizePreset = next;
    await SettingsService.saveSizePreset(next);
    setState(() {});
  }

  Alignment _getAlignment() {
    switch (_settings?.position ?? 'bottomLeft') {
      case 'topLeft':
        return Alignment.topLeft;
      case 'topRight':
        return Alignment.topRight;
      case 'bottomRight':
        return Alignment.bottomRight;
      default:
        return Alignment.bottomLeft;
    }
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
        child: SafeArea(
          minimum: const EdgeInsets.all(16), // 시스템 영역 회피
          child: Align(
            alignment: _getAlignment(),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TreeView(
                active: _stage,
                onTap: _next,
                onDoubleTap: _cycleSize,
                onStageTap: _jumpTo,
                rootName: _settings?.rootName ?? '[Idea]',
                stages: _settings?.stages ?? ['Capture', 'Note', 'Build', 'Test', 'Publish'],
                sizeLabel: _settings?.sizePreset.label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
