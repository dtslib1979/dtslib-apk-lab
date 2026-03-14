import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';

class BgmScreen extends StatefulWidget {
  const BgmScreen({super.key});

  @override
  State<BgmScreen> createState() => _BgmScreenState();
}

class _BgmScreenState extends State<BgmScreen> {
  List<dynamic> _channels = [];
  String _selectedChannel = 'ambient';
  WebViewController? _playerController;
  String? _playingTrack;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    // parksy-audio GitHub에서 먼저 시도
    try {
      final res = await http
          .get(Uri.parse(AppConstants.bgmChannelUrl))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _channels = data['channels'] ?? []);
        return;
      }
    } catch (_) {}
    // 로컬 폴백
    final raw = await rootBundle.loadString('assets/bgm/channels.json');
    final data = jsonDecode(raw);
    setState(() => _channels = data['channels'] ?? []);
  }

  void _playYouTube(String youtubeUrl) {
    final videoId = _extractVideoId(youtubeUrl);
    if (videoId == null) return;
    setState(() => _playingTrack = youtubeUrl);
    _playerController ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _playerController!.loadRequest(Uri.parse(
      'https://www.youtube.com/embed/$videoId?autoplay=1&loop=1&playlist=$videoId',
    ));
  }

  String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
    return uri.queryParameters['v'];
  }

  List<dynamic> get _currentTracks {
    final ch = _channels.firstWhere(
      (c) => c['id'] == _selectedChannel,
      orElse: () => {'tracks': []},
    );
    return ch['tracks'] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.kSurface,
        title: Text('배경음악', style: TextStyle(color: AppConstants.kAccent)),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Column(
        children: [
          // 채널 탭
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _channels.length,
              itemBuilder: (_, i) {
                final ch = _channels[i];
                final sel = _selectedChannel == ch['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedChannel = ch['id']),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppConstants.kAccent : AppConstants.kSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${ch['icon']} ${ch['name']}',
                      style: TextStyle(
                        color: sel ? Colors.black : Colors.white60,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 내장 플레이어
          if (_playingTrack != null && _playerController != null)
            Container(
              height: 120,
              color: Colors.black,
              child: WebViewWidget(controller: _playerController!),
            ),

          // 트랙 목록
          Expanded(
            child: _currentTracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎵', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        const Text('등록된 트랙 없음',
                            style: TextStyle(color: Colors.white38)),
                        const SizedBox(height: 8),
                        Text('parksy-audio → YouTube 업로드 후\nbgm-channel.json에 URL 추가',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _currentTracks.length,
                    itemBuilder: (_, i) {
                      final track = _currentTracks[i];
                      final isPlaying = _playingTrack == track['url'];
                      return ListTile(
                        tileColor: isPlaying
                            ? AppConstants.kAccent.withOpacity(0.1)
                            : AppConstants.kSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Text(isPlaying ? '▶️' : '🎵',
                            style: const TextStyle(fontSize: 22)),
                        title: Text(track['name'] ?? '',
                            style: TextStyle(
                              color: isPlaying ? AppConstants.kAccent : Colors.white70,
                            )),
                        subtitle: Text(track['duration'] ?? '',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                        onTap: () => _playYouTube(track['url']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
