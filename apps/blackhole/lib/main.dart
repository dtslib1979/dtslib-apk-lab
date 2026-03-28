import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BlackholeApp());
}

class BlackholeApp extends StatelessWidget {
  const BlackholeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blackhole',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
        ),
      ),
      home: const BlackholeScreen(),
    );
  }
}

class BlackholeScreen extends StatefulWidget {
  const BlackholeScreen({super.key});

  @override
  State<BlackholeScreen> createState() => _BlackholeScreenState();
}

class _BlackholeScreenState extends State<BlackholeScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final html = await rootBundle.loadString('assets/launcher.html');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D0D0D))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (_) => setState(() {
          _loading = false;
          _error = true;
        }),
        onNavigationRequest: (request) {
          final url = request.url;
          if (!url.startsWith('http') && !url.startsWith('about:')) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadHtmlString(html, baseUrl: 'http://localhost:7777');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // WebView
          if (!_error) WebViewWidget(controller: _controller),

          // 에러 화면
          if (_error) _buildError(),

          // 로딩 스플래시
          if (_loading) _buildSplash(),
        ],
      ),
    );
  }

  Widget _buildSplash() {
    return Container(
      color: const Color(0xFF0D0D0D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 블랙홀 아이콘
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    blurRadius: 20, spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🕳️', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'BLACKHOLE',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'PC 연결 중...',
              style: TextStyle(
                color: Color(0x88F5F5DC),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔌', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'PC 연결 안 됨',
              style: TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'PC에서 start.bat 실행 후\nWSL: adb reverse tcp:7777 tcp:7777',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0x88F5F5DC), fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() { _error = false; _loading = true; _initWebView(); }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('다시 연결', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
