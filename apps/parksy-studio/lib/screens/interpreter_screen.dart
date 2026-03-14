import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../core/constants.dart';

class InterpreterScreen extends StatefulWidget {
  const InterpreterScreen({super.key});

  @override
  State<InterpreterScreen> createState() => _InterpreterScreenState();
}

class _InterpreterScreenState extends State<InterpreterScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppConstants.kBackground)
      ..addJavaScriptChannel(
        'InterpreterChannel',
        onMessageReceived: (msg) async {
          if (msg.message == 'ready') return;
          if (msg.message.startsWith('translate:')) {
            final text = Uri.decodeComponent(msg.message.substring(10));
            final uri = Uri.parse(
              'https://translate.google.com/?sl=auto&tl=ko&text=${Uri.encodeComponent(text)}&op=translate',
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      )
      ..loadFlutterAsset('assets/interpreter/interpreter.html');

    // WebView 마이크 권한 자동 허용 (webkitSpeechRecognition용)
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setOnPlatformPermissionRequest((request) => request.grant());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.kSurface,
        title: Text('동시통역', style: TextStyle(color: AppConstants.kAccent)),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: () =>
                _controller.loadFlutterAsset('assets/interpreter/interpreter.html'),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
