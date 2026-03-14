import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';

class TrimmerScreen extends StatefulWidget {
  final String videoPath;
  final String format;

  const TrimmerScreen({super.key, required this.videoPath, required this.format});

  @override
  State<TrimmerScreen> createState() => _TrimmerScreenState();
}

class _TrimmerScreenState extends State<TrimmerScreen> {
  late final WebViewController _controller;
  String _status = '로드 중...';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppConstants.kBackground)
      ..addJavaScriptChannel(
        'TrimmerChannel',
        onMessageReceived: (msg) {
          if (msg.message == 'ready') {
            // 영상 경로 전달 (file:// 프로토콜)
            final filePath = 'file://${widget.videoPath}';
            _controller.runJavaScript("receiveVideoPath('$filePath')");
            // 포맷 사전 설정
            if (widget.format == 'long') {
              _controller.runJavaScript(
                "document.querySelectorAll('.format-btn')[1].click()",
              );
            }
          } else if (msg.message.startsWith('done:')) {
            setState(() => _status = '✅ ${msg.message.substring(5)}');
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _status = '준비됨'),
      ))
      ..loadFlutterAsset('assets/trimmer/trimmer.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.kSurface,
        title: Text('영상트리머', style: TextStyle(color: AppConstants.kAccent)),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(_status, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
