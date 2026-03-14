import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';

class StudioWebView extends StatefulWidget {
  final String url;
  final String title;

  const StudioWebView({super.key, required this.url, required this.title});

  @override
  State<StudioWebView> createState() => _StudioWebViewState();
}

class _StudioWebViewState extends State<StudioWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    // 풀스크린 진입
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppConstants.kBackground)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) {
          setState(() => _loading = false);
          _injectStudioBridge();
        },
      ))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0 ParksyStudio/1.0',
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    // 풀스크린 해제
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // JS 브릿지 — 나중에 TTS, 자막, 통역 연결 포인트
  void _injectStudioBridge() {
    _controller.runJavaScript('''
      window.ParksyStudio = {
        version: '${AppConstants.version}',
        // Phase 3~7 기능 여기에 추가
        // tts: (text) => ...,
        // subtitle: (text) => ...,
        // bgm: (url) => ...,
      };
      console.log('[ParksyStudio] bridge ready');
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              Container(
                color: AppConstants.kBackground,
                child: Center(
                  child: CircularProgressIndicator(color: AppConstants.kAccent),
                ),
              ),
            // 컨트롤 바 — 탭하면 토글
            if (_controlsVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.fromLTRB(8, 40, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(color: AppConstants.kAccent, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Colors.white70),
            onPressed: () => _controller.loadRequest(Uri.parse(widget.url)),
          ),
        ],
      ),
    );
  }
}
