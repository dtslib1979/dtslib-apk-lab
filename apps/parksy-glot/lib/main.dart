/// Parksy Glot v2.0
/// Axis-shell 패턴: 얇은 오버레이 APK + WebView → PC glot.py 자막 수신
///
/// 구조:
///   main() → 메인 앱 (PC IP 설정 + 오버레이 ON/OFF)
///   overlayMain() → 오버레이 (WebView → http://PC_IP:8766/subtitle)

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ─── 오버레이 엔트리포인트 ─────────────────────────────────────────────────

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _GlotOverlayApp());
}

class _GlotOverlayApp extends StatefulWidget {
  const _GlotOverlayApp();

  @override
  State<_GlotOverlayApp> createState() => _GlotOverlayAppState();
}

class _GlotOverlayAppState extends State<_GlotOverlayApp> {
  WebViewController? _ctrl;
  String _url = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 메인 앱에서 shareData()로 URL 수신
    FlutterOverlayWindow.overlayListener.listen((data) {
      final s = data?.toString() ?? '';
      if (s.startsWith('http')) {
        _loadUrl(s);
      }
    });

    // SharedPreferences에서 저장된 PC IP 읽기
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('glot_pc_ip') ?? '';
    if (ip.isNotEmpty) {
      _loadUrl('http://$ip:8766/subtitle');
    }
  }

  void _loadUrl(String url) {
    setState(() => _url = url);
    _ctrl ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);
    _ctrl!.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: _url.isEmpty
            ? const SizedBox.shrink()
            : WebViewWidget(controller: _ctrl!),
      ),
    );
  }
}

// ─── 메인 앱 엔트리포인트 ──────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GlotApp());
}

class GlotApp extends StatelessWidget {
  const GlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Glot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _GlotHomeScreen(),
    );
  }
}

class _GlotHomeScreen extends StatefulWidget {
  const _GlotHomeScreen();

  @override
  State<_GlotHomeScreen> createState() => _GlotHomeScreenState();
}

class _GlotHomeScreenState extends State<_GlotHomeScreen> {
  final _ipCtrl = TextEditingController();
  bool _overlayActive = false;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('glot_pc_ip') ?? '';
    _ipCtrl.text = ip;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    setState(() {
      _permissionGranted = granted;
    });
  }

  Future<void> _saveIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('glot_pc_ip', _ipCtrl.text.trim());
  }

  Future<void> _toggleOverlay() async {
    if (!_permissionGranted) {
      final granted = await FlutterOverlayWindow.requestPermission();
      if (granted != true) return;
      setState(() => _permissionGranted = true);
    }

    if (_overlayActive) {
      await FlutterOverlayWindow.closeOverlay();
      setState(() => _overlayActive = false);
    } else {
      final ip = _ipCtrl.text.trim();
      if (ip.isEmpty) {
        _showSnack('PC IP를 입력하세요');
        return;
      }
      await _saveIp();

      await FlutterOverlayWindow.showOverlay(
        height: 200,
        width: WindowSize.fullCover,
        alignment: OverlayAlignment.bottomCenter,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Glot',
      );

      // URL을 오버레이 WebView에 전달
      await FlutterOverlayWindow.shareData('http://$ip:8766/subtitle');
      setState(() => _overlayActive = true);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text(
          'Parksy Glot v2.0',
          style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PC IP 주소',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ipCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '예: 100.74.5.10',
                hintStyle: const TextStyle(color: Color(0xFF444444)),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixText: ':8766',
                suffixStyle: const TextStyle(color: Color(0xFF888888)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _permissionGranted
                  ? '오버레이 권한: ✅ 허용됨'
                  : '오버레이 권한: ❌ 미허용 (버튼 누르면 설정으로 이동)',
              style: TextStyle(
                color: _permissionGranted
                    ? const Color(0xFF98D98E)
                    : const Color(0xFFFF6B6B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _toggleOverlay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _overlayActive
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _overlayActive ? '■  자막 오버레이 끄기' : '▶  자막 오버레이 켜기',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Divider(color: Color(0xFF222222)),
            const SizedBox(height: 16),
            const Text(
              '사용 방법',
              style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _step('1', 'PC에서 glot.py 실행 (WSL2)'),
            _step('2', 'PC IP 입력 후 [자막 오버레이 켜기]'),
            _step('3', 'PC Chrome에서 [▶ 자막 시작] 클릭'),
            _step('4', '자막이 태블릿 화면 위에 오버레이됨'),
            _step('5', 'scrcpy로 캡처하면 자막이 영상에 박힘'),
          ],
        ),
      ),
    );
  }

  Widget _step(String n, String txt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              shape: BoxShape.circle,
            ),
            child: Text(n,
                style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(txt,
                style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }
}
