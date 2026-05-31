import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/api_config.dart';

class ShareHandler extends StatefulWidget {
  const ShareHandler({super.key});

  @override
  State<ShareHandler> createState() => _ShareHandlerState();
}

class _ShareHandlerState extends State<ShareHandler> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.parksy.capture/share');

  String _status = 'Receiving...';
  IconData _icon = Icons.downloading;
  Color _iconColor = const Color(0xFF58A6FF);
  bool _isDone = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleShare());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    try {
      final text = await platform.invokeMethod<String>('getSharedText');
      if (text == null || text.isEmpty) {
        _updateStatus('No text received', Icons.error_outline, const Color(0xFFF85149));
        _finish();
        return;
      }
      setState(() { _status = 'Saving locally...'; _icon = Icons.save; });
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fname = 'ParksyLog_$ts.md';
      final content = _toMarkdown(text);
      final localOk = await _saveLocal(fname, content);
      if (!localOk) {
        _updateStatus('Save failed', Icons.error, const Color(0xFFF85149));
        _finish();
        return;
      }
      if (!ApiConfig.isGitHubConfigured) {
        _updateStatus('Saved locally', Icons.check_circle, const Color(0xFF7EE787));
        _finish();
        return;
      }
      setState(() { _status = 'Syncing to GitHub...'; _icon = Icons.cloud_upload; });
      final syncResult = await _syncToGitHub(fname, content);
      if (syncResult == null) {
        _updateStatus('Saved & Synced', Icons.cloud_done, const Color(0xFF7EE787));
      } else {
        _updateStatus('⚠️ GitHub 실패: $syncResult', Icons.cloud_off, const Color(0xFFF85149));
        _finish(hasError: true);
      }
    } catch (e) {
      _updateStatus('Error: $e', Icons.error, const Color(0xFFF85149));
      _finish(hasError: true);
    }
  }

  void _updateStatus(String status, IconData icon, Color color) {
    if (!mounted) return;
    setState(() { _status = status; _icon = icon; _iconColor = color; _isDone = true; });
    _animController.stop();
  }

  Future<bool> _saveLocal(String filename, String content) async {
    try {
      final result = await platform.invokeMethod<bool>('saveToDownloads', {'filename': filename, 'content': content});
      return result ?? false;
    } catch (e) { return false; }
  }

  Future<String?> _syncToGitHub(String filename, String content) async {
    try {
      if (ApiConfig.githubToken == null || ApiConfig.githubToken!.isEmpty) return 'Token 없음';
      final now = DateTime.now();
      final path = 'logs/${now.year}/${now.month.toString().padLeft(2, '0')}/$filename';
      final res = await http.put(
        Uri.parse('https://api.github.com/repos/${ApiConfig.githubRepo}/contents/$path'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.githubToken}',
          'Accept': 'application/vnd.github+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': 'Add $filename', 'content': base64Encode(utf8.encode(content))}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 201 || res.statusCode == 200) return null;
      if (res.statusCode == 401) return 'Token 만료/무효';
      if (res.statusCode == 403) return 'Token 권한 부족';
      if (res.statusCode == 404) return 'Repo 없음';
      return 'HTTP ${res.statusCode}';
    } on TimeoutException { return '타임아웃'; }
    catch (e) { return '네트워크 오류'; }
  }

  String _toMarkdown(String text) {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return '---\ndate: $ts\nsource: android-share\n---\n\n$text\n';
  }

  void _finish({bool hasError = false}) {
    Future.delayed(Duration(seconds: hasError ? 3 : 2), () {
      if (mounted) SystemNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isDone
                ? Icon(_icon, size: 64, color: _iconColor)
                : RotationTransition(
                    turns: _animController,
                    child: Icon(_icon, size: 64, color: _iconColor),
                  ),
            const SizedBox(height: 24),
            Text(_status, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
