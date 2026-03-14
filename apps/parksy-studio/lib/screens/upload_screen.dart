import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class UploadScreen extends StatefulWidget {
  final String? videoPath;
  const UploadScreen({super.key, this.videoPath});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _accessToken;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _privacy = 'private';
  bool _uploading = false;
  double _progress = 0;
  String _status = '';

  // YouTube OAuth (Authorization Code + PKCE via Chrome Custom Tab)
  static const _clientId =
      '390585643473-mqhas2b57qjlefejt7ptl8jrqmlkllge.apps.googleusercontent.com';
  static const _redirectScheme = 'com.parksy.studio';
  static const _redirectUri = '$_redirectScheme://oauth2callback';
  static const _scope = 'https://www.googleapis.com/auth/youtube.upload';

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
    setState(() => _accessToken = token);
  }

  Future<void> _startOAuth() async {
    try {
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'token',
        'scope': _scope,
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _redirectScheme,
      );

      // result: com.parksy.studio://oauth2callback#access_token=xxx&...
      final fragment = Uri.parse(result).fragment;
      final params = Uri.splitQueryString(fragment);
      final token = params['access_token'];
      if (token != null) {
        await _saveToken(token);
        setState(() => _status = '✅ 로그인 완료');
      } else {
        setState(() => _status = '⚠️ 토큰 수신 실패');
      }
    } catch (e) {
      setState(() => _status = '⚠️ 로그인 취소 또는 실패');
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('yt_access_token');
    setState(() { _accessToken = null; _status = ''; });
  }

  Future<void> _upload() async {
    if (_accessToken == null) { await _startOAuth(); return; }
    if (widget.videoPath == null) {
      setState(() => _status = '⚠️ 영상 없음 — 트리머에서 먼저 변환하세요.');
      return;
    }
    setState(() { _uploading = true; _progress = 0; _status = '업로드 준비 중...'; });

    try {
      final file = File(widget.videoPath!);
      final fileSize = await file.length();

      // 1. Resumable session 시작
      final initRes = await http.post(
        Uri.parse('https://www.googleapis.com/upload/youtube/v3/videos'
            '?uploadType=resumable&part=snippet,status'),
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

      if (initRes.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('yt_access_token');
        setState(() { _accessToken = null; _uploading = false; _status = '토큰 만료 — 다시 로그인하세요.'; });
        return;
      }
      if (initRes.statusCode != 200) {
        throw Exception('세션 시작 실패: ${initRes.statusCode}');
      }

      final uploadUrl = initRes.headers['location']!;
      setState(() => _status = '업로드 중...');

      // 2. 청크 업로드 (10MB 단위, RandomAccessFile 사용)
      const chunkSize = 10 * 1024 * 1024;
      int uploaded = 0;
      final raf = await file.open(mode: FileMode.read);

      try {
        while (uploaded < fileSize) {
          final end = (uploaded + chunkSize).clamp(0, fileSize);
          final chunkLen = end - uploaded;
          await raf.setPosition(uploaded);
          final bytes = await raf.read(chunkLen);

          http.Response? res;
          for (int attempt = 0; attempt < 3; attempt++) {
            try {
              res = await http.put(
                Uri.parse(uploadUrl),
                headers: {
                  'Authorization': 'Bearer $_accessToken',
                  'Content-Type': 'video/mp4',
                  'Content-Range': 'bytes $uploaded-${end - 1}/$fileSize',
                },
                body: bytes,
              );
              break;
            } catch (_) {
              if (attempt == 2) rethrow;
              await Future.delayed(Duration(seconds: (1 << attempt)));
            }
          }

          setState(() => _progress = end / fileSize);

          if (res!.statusCode == 200 || res.statusCode == 201) {
            final data = jsonDecode(res.body);
            setState(() {
              _status = '✅ 업로드 완료!\nhttps://youtu.be/${data['id']}';
              _uploading = false;
              _progress = 1.0;
            });
            return;
          } else if (res.statusCode == 308) {
            uploaded = end;
            continue;
          } else {
            throw Exception('청크 실패: ${res.statusCode}');
          }
        }
      } finally {
        await raf.close();
      }

      setState(() { _uploading = false; _status = '⚠️ 업로드 상태 불명확 — YouTube Studio 확인 필요.'; });
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 인증 상태
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppConstants.kSurface, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text(
                _accessToken != null ? '✅ 로그인됨' : '⚠️ 미로그인',
                style: TextStyle(color: _accessToken != null ? Colors.greenAccent : Colors.orange),
              ),
              const Spacer(),
              if (_accessToken == null)
                TextButton(
                  onPressed: _startOAuth,
                  child: Text('Google 로그인', style: TextStyle(color: AppConstants.kAccent)),
                )
              else
                TextButton(
                  onPressed: _signOut,
                  child: const Text('로그아웃', style: TextStyle(color: Colors.white38)),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // 영상 파일
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppConstants.kSurface, borderRadius: BorderRadius.circular(10)),
            child: Text(
              widget.videoPath != null
                  ? '🎬 ${p.basename(widget.videoPath!)}'
                  : '⚠️ 영상 없음 — 트리머에서 먼저 변환하세요',
              style: TextStyle(
                  color: widget.videoPath != null ? Colors.white70 : Colors.orange, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          // 제목
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '제목', labelStyle: const TextStyle(color: Colors.white54),
              filled: true, fillColor: AppConstants.kSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          // 설명
          TextField(
            controller: _descCtrl, maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '설명 (선택)', labelStyle: const TextStyle(color: Colors.white54),
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
              labelText: '공개 설정', labelStyle: const TextStyle(color: Colors.white54),
              filled: true, fillColor: AppConstants.kSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'private',  child: Text('비공개')),
              DropdownMenuItem(value: 'unlisted', child: Text('일부 공개')),
              DropdownMenuItem(value: 'public',   child: Text('공개')),
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
        ]),
      ),
    );
  }
}
