import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';

class UploadScreen extends StatefulWidget {
  final String? videoPath;
  const UploadScreen({super.key, this.videoPath});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // OAuth
  String? _accessToken;
  bool _authLoading = false;
  WebViewController? _authController;

  // 업로드 메타
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _privacy = 'private';
  bool _uploading = false;
  double _progress = 0;
  String _status = '';

  // YouTube OAuth 설정 (공개 클라이언트 ID — YouTube Data API v3 개인 앱용)
  static const _clientId =
      '390585643473-mqhas2b57qjlefejt7ptl8jrqmlkllge.apps.googleusercontent.com';
  static const _redirectUri = 'https://localhost';
  static const _scope =
      'https://www.googleapis.com/auth/youtube.upload';

  @override
  void initState() {
    super.initState();
    _loadToken();
    if (widget.videoPath != null) {
      _titleCtrl.text = p.basenameWithoutExtension(widget.videoPath!);
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('yt_access_token');
    if (token != null) setState(() => _accessToken = token);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yt_access_token', token);
    setState(() { _accessToken = token; _authLoading = false; });
  }

  void _startOAuth() {
    setState(() => _authLoading = true);
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'token',
      'scope': _scope,
    });

    _authController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          if (req.url.startsWith(_redirectUri)) {
            final fragment = Uri.parse(req.url).fragment;
            final params = Uri.splitQueryString(fragment);
            final token = params['access_token'];
            if (token != null) _saveToken(token);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(authUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.kBackground,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            AppBar(
              backgroundColor: AppConstants.kSurface,
              title: Text('Google 로그인', style: TextStyle(color: AppConstants.kAccent)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _authLoading = false);
                },
              ),
            ),
            Expanded(child: WebViewWidget(controller: _authController!)),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    if (_accessToken == null) { _startOAuth(); return; }
    if (widget.videoPath == null) {
      setState(() => _status = '⚠️ 영상 파일 없음. 트리머에서 먼저 변환하세요.');
      return;
    }
    setState(() { _uploading = true; _progress = 0; _status = '업로드 준비 중...'; });

    try {
      final file = File(widget.videoPath!);
      final fileSize = await file.length();

      // 1단계: 업로드 세션 시작
      final initRes = await http.post(
        Uri.parse('https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'X-Upload-Content-Type': 'video/mp4',
          'X-Upload-Content-Length': '$fileSize',
        },
        body: jsonEncode({
          'snippet': {
            'title': _titleCtrl.text.trim().isEmpty ? 'Parksy Studio' : _titleCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'categoryId': '22',
          },
          'status': {'privacyStatus': _privacy},
        }),
      );

      if (initRes.statusCode != 200) {
        if (initRes.statusCode == 401) {
          // 토큰 만료
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('yt_access_token');
          setState(() { _accessToken = null; _uploading = false; _status = '토큰 만료. 다시 로그인하세요.'; });
          return;
        }
        throw Exception('세션 시작 실패: ${initRes.statusCode}');
      }

      final uploadUrl = initRes.headers['location']!;
      setState(() => _status = '업로드 중...');

      // 2단계: 파일 업로드 (청크 업로드)
      const chunkSize = 5 * 1024 * 1024; // 5MB
      final fileStream = file.openRead();
      int uploaded = 0;

      await for (final chunk in fileStream.expand((b) => [b]).toList().then(
        (_) => Stream.fromIterable(
          List.generate((fileSize / chunkSize).ceil(), (i) {
            final start = i * chunkSize;
            final end = (start + chunkSize).clamp(0, fileSize);
            return [start, end];
          }),
        ),
      )) {
        final start = chunk[0];
        final end = chunk[1];
        final bytes = await file.openRead(start, end).fold<List<int>>(
          [], (a, b) => a..addAll(b));

        final res = await http.put(
          Uri.parse(uploadUrl),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'video/mp4',
            'Content-Range': 'bytes $start-${end - 1}/$fileSize',
          },
          body: bytes,
        );

        uploaded = end;
        setState(() => _progress = uploaded / fileSize);

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          setState(() {
            _status = '✅ 업로드 완료!\nhttps://youtu.be/${data['id']}';
            _uploading = false;
            _progress = 1.0;
          });
          return;
        }
      }
    } catch (e) {
      setState(() { _uploading = false; _status = '❌ 오류: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.kSurface,
        title: Text('YouTube 업로드', style: TextStyle(color: AppConstants.kAccent)),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 인증 상태
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.kSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(_accessToken != null ? '✅ 로그인됨' : '⚠️ 미로그인',
                      style: TextStyle(color: _accessToken != null ? Colors.greenAccent : Colors.orange)),
                  const Spacer(),
                  if (_accessToken == null)
                    TextButton(
                      onPressed: _startOAuth,
                      child: Text('Google 로그인', style: TextStyle(color: AppConstants.kAccent)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 영상 파일
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.kSurface, borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.videoPath != null
                    ? '🎬 ${p.basename(widget.videoPath!)}'
                    : '⚠️ 영상 없음 — 트리머에서 먼저 변환하세요',
                style: TextStyle(color: widget.videoPath != null ? Colors.white70 : Colors.orange, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            // 제목
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '제목',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: AppConstants.kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // 설명
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '설명 (선택)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: AppConstants.kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // 공개 설정
            DropdownButtonFormField<String>(
              value: _privacy,
              dropdownColor: AppConstants.kSurface,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '공개 설정',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: AppConstants.kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: 'private',   child: Text('비공개')),
                DropdownMenuItem(value: 'unlisted',  child: Text('일부 공개')),
                DropdownMenuItem(value: 'public',    child: Text('공개')),
              ],
              onChanged: (v) => setState(() => _privacy = v!),
            ),
            const SizedBox(height: 24),

            // 진행바
            if (_uploading) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppConstants.kSurface,
                valueColor: AlwaysStoppedAnimation(AppConstants.kAccent),
              ),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppConstants.kAccent)),
              const SizedBox(height: 16),
            ],

            // 상태
            if (_status.isNotEmpty)
              Text(_status, textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _status.startsWith('✅') ? Colors.greenAccent : Colors.white54,
                    fontSize: 13,
                  )),
            const SizedBox(height: 16),

            // 업로드 버튼
            ElevatedButton(
              onPressed: _uploading ? null : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.kAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _uploading ? '업로드 중...' : '☁️ YouTube 업로드',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
