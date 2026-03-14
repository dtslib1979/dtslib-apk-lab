import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
            // Gemini Nano 실패 시 Google Translate 웹 열기
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
            onPressed: () => _controller.loadFlutterAsset('assets/interpreter/interpreter.html'),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
