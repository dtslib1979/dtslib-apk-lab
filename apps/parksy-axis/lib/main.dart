/// Parksy Axis v9.0.0 Ultimate Edition
/// 방송용 사고 단계 오버레이 - FSM 기반 상태 전이
///
/// v9.0.0: 완전 리팩토링
///   - sealed class Result 패턴
///   - immutable 설정 모델 + copyWith
///   - 8개 테마 (그라데이션 지원)
///   - 6개 폰트 프리셋
///   - 탭 기반 설정 UI
///   - 펄스 애니메이션
///   - core/ 모듈 분리

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'app.dart';
import 'core/constants.dart';
import 'widgets/tree_view.dart';
import 'services/settings_service.dart';
import 'models/settings.dart';
import 'models/theme.dart';

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
  AxisSettings _cfg = const AxisSettings();
  bool _init = true;
  int _currentW = OverlayDefaults.width;
  int _currentH = OverlayDefaults.height;

  ServerSocket? _ctl;

  @override
  void initState() {
    super.initState();
    _listenForData();
    _load();
    _startCtlSocket();
  }

  /// 터미널 라우팅용 localhost 커맨드 소켓 (트랙 C: teach_dispatch.sh).
  /// `echo next | nc 127.0.0.1 8492`  ·  next / prev / reset / jump N
  Future<void> _startCtlSocket() async {
    try {
      _ctl = await ServerSocket.bind(InternetAddress.loopbackIPv4, 8492, shared: true);
      _ctl!.listen((sock) {
        sock.cast<List<int>>().transform(utf8.decoder).listen((line) {
          for (final raw in line.split('\n')) {
            final cmd = raw.trim().toLowerCase();
            if (cmd.isEmpty) continue;
            if (cmd == 'next') _next();
            else if (cmd == 'prev') {
              final n = _cfg.stages.length;
              if (n > 0) setState(() => _idx = (_idx - 1 + n) % n);
            } else if (cmd == 'reset') _jump(0);
            else if (cmd.startsWith('jump ')) {
              final i = int.tryParse(cmd.substring(5).trim());
              if (i != null) _jump(i);
            }
          }
        });
      });
      debugPrint('[Overlay] ctl socket :8492');
    } catch (e) {
      debugPrint('[Overlay] ctl socket fail: $e');
    }
  }

  @override
  void dispose() {
    _ctl?.close();
    super.dispose();
  }

  /// 메인 앱에서 shareData()로 설정을 직접 수신
  void _listenForData() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      try {
        debugPrint('[Overlay] received shareData type=${data.runtimeType}');
        final str = (data is String) ? data : data.toString();
        if (str.isNotEmpty) {
          final json = jsonDecode(str) as Map<String, dynamic>;
          final settings = AxisSettings.fromJson(json);
          if (settings.isValid) {
            _applySettings(settings);
            debugPrint('[Overlay] shareData applied: theme=${settings.themeId} stages=${settings.stages.length}');
          }
        }
      } catch (e) {
        debugPrint('[Overlay] shareData error: $e');
      }
    });
  }

  void _applySettings(AxisSettings settings) {
    _cfg = settings;
    _currentW = _cfg.scaledWidth;
    _currentH = _cfg.scaledHeight;
    if (mounted) setState(() => _init = false);
  }

  Future<void> _load() async {
    debugPrint('[Overlay] _load() called');

    // 파일 시스템에서 설정 로드 (프로세스 간 동기화 보장)
    final result = await SettingsService.loadForOverlay();
    final loaded = result.getOrDefault(const AxisSettings());

    debugPrint('[Overlay] loaded config: $loaded');
    debugPrint('[Overlay] stages: ${loaded.stages}');

    _applySettings(loaded);
  }

  /// FSM: s → (s+1) mod n
  void _next() {
    final n = _cfg.stages.length;
    setState(() => _idx = (_idx + 1) % n);
  }

  /// Direct jump: s → i
  void _jump(int i) => setState(() => _idx = i);

  @override
  Widget build(BuildContext context) {
    if (_init) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(
          color: Colors.black54,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          ),
        ),
      );
    }

    final t = AxisTheme.byId(_cfg.themeId);
    final f = AxisFont.byId(_cfg.fontId);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _next,
          child: SizedBox(
            width: _currentW.toDouble(),
            height: _currentH.toDouble(),
            child: TreeView(
              active: _idx,
              onTap: _next,
              onJump: _jump,
              root: _cfg.rootName,
              items: _cfg.stages,
              theme: t,
              font: f,
              opacity: _cfg.bgOpacity,
              stroke: _cfg.strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}
