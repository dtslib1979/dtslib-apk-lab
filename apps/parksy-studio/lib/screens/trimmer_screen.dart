import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
  HttpServer? _server;
  int _port = 0;
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
            // 로컬 서버에서 영상 서빙 — same-origin이라 cross-origin 이슈 없음
            _controller.runJavaScript(
              "receiveVideoPath('http://localhost:$_port/video.mp4')",
            );
            if (widget.format == 'long') {
              _controller.runJavaScript(
                "document.querySelectorAll('.format-btn')[1].click()",
              );
            }
          } else if (msg.message.startsWith('download|')) {
            // JS에서 FFmpeg 출력 base64로 수신 → 파일 저장
            _saveFile(msg.message);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _status = '준비됨'),
      ));

    _startServer();
  }

  Future<void> _startServer() async {
    final htmlContent = await rootBundle.loadString('assets/trimmer/trimmer.html');
    final videoFile = File(widget.videoPath);

    // 동적 포트 할당
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    _server!.listen((req) async {
      if (req.uri.path == '/video.mp4') {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType('video', 'mp4');
        await req.response.addStream(videoFile.openRead());
      } else {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.html;
        req.response.write(htmlContent);
      }
      await req.response.close();
    });

    _controller.loadRequest(Uri.parse('http://localhost:$_port/'));
  }

  Future<void> _saveFile(String raw) async {
    // format: 'download|filename|base64data'
    final firstPipe = raw.indexOf('|');
    final secondPipe = raw.indexOf('|', firstPipe + 1);
    final filename = raw.substring(firstPipe + 1, secondPipe);
    final b64 = raw.substring(secondPipe + 1);

    try {
      setState(() => _status = '💾 저장 중...');
      final bytes = base64Decode(b64);
      final extDir = await getExternalStorageDirectory();
      final outDir = Directory('${extDir!.path}/ParksyStudio');
      await outDir.create(recursive: true);
      final file = File('${outDir.path}/$filename');
      await file.writeAsBytes(bytes);
      if (mounted) setState(() => _status = '✅ $filename');
    } catch (e) {
      if (mounted) setState(() => _status = '❌ 저장 실패: $e');
    }
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
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
