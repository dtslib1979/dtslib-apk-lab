import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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
            final encoded = Uri.encodeFull(widget.videoPath);
            _controller.runJavaScript("receiveVideoPath('file://$encoded')");
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
      ));

    // file:// → file:// fetch 허용
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setAllowFileAccess(true);
    }

    _loadHtml();
  }

  // asset을 temp 파일로 복사 → file:// 로드
  // (flutter asset URL에서 fetch('file://...')는 cross-origin 차단됨)
  Future<void> _loadHtml() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/trimmer.html');
    final content = await rootBundle.loadString('assets/trimmer/trimmer.html');
    await file.writeAsString(content);
    _controller.loadRequest(Uri.parse('file://${file.path}'));
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
              child: Text(_status,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
