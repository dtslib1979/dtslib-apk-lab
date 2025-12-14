import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const CaptureApp());
}

class CaptureApp extends StatelessWidget {
  const CaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Capture',
      theme: ThemeData.dark(),
      home: const ShareHandler(),
    );
  }
}

class ShareHandler extends StatefulWidget {
  const ShareHandler({super.key});

  @override
  State<ShareHandler> createState() => _ShareHandlerState();
}

class _ShareHandlerState extends State<ShareHandler> {
  static const platform = MethodChannel('com.parksy.capture/share');
  
  // TODO: Worker URL 설정 필요
  static const workerUrl = 'https://YOUR_WORKER.workers.dev';
  
  @override
  void initState() {
    super.initState();
    _handleShare();
  }

  Future<void> _handleShare() async {
    try {
      final text = await platform.invokeMethod<String>('getSharedText');
      if (text == null || text.isEmpty) {
        _showToast('No text received');
        _finish();
        return;
      }
      
      // Step 1: Local save (MUST succeed)
      final localOk = await _saveLocal(text);
      if (!localOk) {
        _showToast('Error! Save Failed ❌');
        _finish();
        return;
      }
      
      // Step 2: Cloud save (MAY fail)
      final cloudOk = await _saveCloud(text);
      
      if (cloudOk) {
        _showToast('Saved Local & Cloud 🚀');
      } else {
        _showToast('Saved Local Only ✅');
      }
      
      _finish();
    } catch (e) {
      _showToast('Error: $e');
      _finish();
    }
  }

  Future<bool> _saveLocal(String text) async {
    try {
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fname = 'ParksyLog_$ts.md';
      final content = _toMarkdown(text);
      
      // Invoke native to save via MediaStore
      final result = await platform.invokeMethod<bool>(
        'saveToDownloads',
        {'filename': fname, 'content': content},
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _saveCloud(String text) async {
    try {
      final ts = DateTime.now().toIso8601String();
      final res = await http.post(
        Uri.parse(workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'source': 'android',
          'ts': ts,
        }),
      ).timeout(const Duration(seconds: 5));
      
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  String _toMarkdown(String text) {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return '''---
date: $ts
source: android-share
---

$text
''';
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _finish() {
    Future.delayed(const Duration(seconds: 2), () {
      SystemNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
