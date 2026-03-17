import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:http/http.dart' as http;

// Telegram bot config (personal use)
const _botToken = '8669426963:AAGvsn8ZnWgkTccw2G2AqgxHbq9RVtmBZMA';
const _chatId = '6858098283';

const _kBg = Color(0xFF0D0D0D);
const _kSurface = Color(0xFF1A1A1A);
const _kGold = Color(0xFFE8D5B7);
const _kDim = Color(0xFF2A2A2A);
const _kAccent = Color(0xFFD4AF37);

enum AppState { idle, downloading, ready, trimming, sending, done }

class _Preset {
  final String label;
  final int seconds;
  const _Preset(this.label, this.seconds);
}

const _presets = [
  _Preset('10s', 10),
  _Preset('20s', 20),
  _Preset('30s', 30),
  _Preset('1 min', 60),
  _Preset('3 min', 180),
];

class MelodyScreen extends StatefulWidget {
  const MelodyScreen({super.key});

  @override
  State<MelodyScreen> createState() => _MelodyScreenState();
}

class _MelodyScreenState extends State<MelodyScreen> {
  static const _intentChannel = MethodChannel('com.parksy.melody/intent');

  final _urlController = TextEditingController();
  final _player = AudioPlayer();

  AppState _state = AppState.idle;
  String _statusMsg = '';
  double _downloadProgress = 0.0;

  String? _downloadedPath;
  Duration _totalDuration = Duration.zero;
  Duration _position = Duration.zero;
  int _selectedPreset = 30; // default 30s
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
    _checkSharedUrl();
  }

  Future<void> _checkSharedUrl() async {
    try {
      final url = await _intentChannel.invokeMethod<String>('getSharedUrl');
      if (url != null && url.isNotEmpty && mounted) {
        _urlController.text = url;
        setState(() => _statusMsg = 'YouTube URL received from share');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // yt-dlp via Termux RUN_COMMAND — output always /sdcard/Music/melody_dl.mp3
  static const _dlPath = '/sdcard/Music/melody_dl.mp3';

  Future<void> _download() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _state = AppState.downloading;
      _downloadProgress = 0.0;
      _statusMsg = 'Starting yt-dlp...';
    });

    try {
      // Delete stale file
      final outFile = File(_dlPath);
      if (await outFile.exists()) await outFile.delete();

      // Kick off yt-dlp in Termux background
      await _intentChannel.invokeMethod('runYtDlp', {
        'url': url,
        'output': _dlPath,
      });

      setState(() => _statusMsg = 'Downloading via yt-dlp...');

      // Poll until file is stable (size unchanged for 2s) — max 3 min
      int lastSize = -1;
      int stableCount = 0;
      bool done = false;

      for (int i = 0; i < 180; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;

        if (await outFile.exists()) {
          final size = await outFile.length();
          if (size > 50000 && size == lastSize) {
            stableCount++;
            if (stableCount >= 2) { done = true; break; }
          } else {
            stableCount = 0;
          }
          lastSize = size;
        }
        setState(() => _downloadProgress = (i / 60).clamp(0.0, 0.95));
      }

      if (!done) throw Exception('Timeout. Check Termux notification.');

      await _player.setFilePath(_dlPath);
      final dur = _player.duration;

      setState(() {
        _downloadedPath = _dlPath;
        _totalDuration = dur ?? Duration.zero;
        _state = AppState.ready;
        _statusMsg = 'Ready — ${_fmt(dur ?? Duration.zero)}';
        _downloadProgress = 1.0;
      });
    } catch (e) {
      setState(() {
        _state = AppState.idle;
        _statusMsg = 'Error: $e';
      });
    }
  }

  Future<void> _cutAndSend() async {
    if (_downloadedPath == null) return;

    final endSec = _selectedPreset;
    final actualEnd = _totalDuration.inSeconds > 0
        ? endSec.clamp(1, _totalDuration.inSeconds)
        : endSec;

    setState(() {
      _state = AppState.trimming;
      _statusMsg = 'Trimming 0~${endSec}s...';
    });
    await _player.stop();

    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/melody_cut_${endSec}s.mp3';

    final cmd = '-y -i "$_downloadedPath" -t $actualEnd -acodec libmp3lame -ab 192k "$outPath"';
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();

    if (!ReturnCode.isSuccess(rc)) {
      setState(() {
        _state = AppState.ready;
        _statusMsg = 'Trim failed';
      });
      return;
    }

    setState(() {
      _state = AppState.sending;
      _statusMsg = 'Sending to Telegram...';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.telegram.org/bot$_botToken/sendDocument'),
      );
      request.fields['chat_id'] = _chatId;
      request.files.add(await http.MultipartFile.fromPath('document', outPath,
          filename: 'melody_${endSec}s.mp3'));

      final response = await request.send();
      final statusCode = response.statusCode;

      setState(() {
        _state = AppState.done;
        _statusMsg = statusCode == 200
            ? '✅ Sent! Check @parksy_bridges_bot'
            : '❌ Telegram error $statusCode';
      });
    } catch (e) {
      setState(() {
        _state = AppState.ready;
        _statusMsg = 'Send failed: $e';
      });
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _busy =>
      _state == AppState.downloading ||
      _state == AppState.trimming ||
      _state == AppState.sending;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: const Text('🎵 Parksy Melody',
            style: TextStyle(color: _kGold, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildUrlCard(),
            const SizedBox(height: 12),
            if (_state != AppState.idle) _buildStatusCard(),
            if (_state == AppState.downloading) ...[
              const SizedBox(height: 8),
              _buildProgressBar(),
            ],
            if (_state == AppState.ready ||
                _state == AppState.trimming ||
                _state == AppState.sending ||
                _state == AppState.done) ...[
              const SizedBox(height: 12),
              _buildPlayerCard(),
              const SizedBox(height: 12),
              _buildPresetCard(),
              const SizedBox(height: 16),
              _buildSendButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUrlCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YouTube URL',
              style: TextStyle(color: _kGold, fontSize: 12,
                  fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            enabled: !_busy,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste URL or share from YouTube app',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: _kDim,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _urlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                      onPressed: () => setState(() => _urlController.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_busy ||
                      _urlController.text.trim().isEmpty ||
                      _state == AppState.done)
                  ? null
                  : _download,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _state == AppState.downloading ? 'Downloading...' : 'DOWNLOAD',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (_busy)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kGold,
              ),
            ),
          if (_busy) const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMsg,
              style: TextStyle(
                color: _state == AppState.done ? const Color(0xFF4CAF50) : _kGold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _downloadProgress,
            backgroundColor: _kDim,
            valueColor: const AlwaysStoppedAnimation<Color>(_kAccent),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(_downloadProgress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPlayerCard() {
    final progress = _totalDuration.inMilliseconds > 0
        ? _position.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_position),
                  style: const TextStyle(color: _kGold, fontSize: 13)),
              Text(_fmt(_totalDuration),
                  style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kAccent,
              inactiveTrackColor: _kDim,
              thumbColor: _kGold,
              overlayColor: _kGold.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: _busy
                  ? null
                  : (val) {
                      final pos = Duration(
                          milliseconds:
                              (val * _totalDuration.inMilliseconds).round());
                      _player.seek(pos);
                    },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: _kGold),
                onPressed: _busy
                    ? null
                    : () => _player.seek(Duration(
                        seconds: (_position.inSeconds - 10).clamp(0,
                            _totalDuration.inSeconds))),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _busy
                    ? null
                    : () {
                        if (_isPlaying) {
                          _player.pause();
                        } else {
                          _player.play();
                        }
                      },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _busy ? _kDim : _kAccent,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.forward_10, color: _kGold),
                onPressed: _busy
                    ? null
                    : () => _player.seek(Duration(
                        seconds: (_position.inSeconds + 10).clamp(0,
                            _totalDuration.inSeconds))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CUT PRESET',
              style: TextStyle(
                  color: _kGold, fontSize: 12,
                  fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final selected = _selectedPreset == p.seconds;
              return GestureDetector(
                onTap: _busy ? null : () => setState(() => _selectedPreset = p.seconds),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? _kAccent : _kDim,
                    borderRadius: BorderRadius.circular(8),
                    border: selected
                        ? null
                        : Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white70,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Will cut from 0:00 to ${_fmt(Duration(seconds: _selectedPreset))}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend = _state == AppState.ready || _state == AppState.done;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: canSend ? _cutAndSend : null,
        icon: const Icon(Icons.send, size: 18),
        label: Text(
          _state == AppState.trimming
              ? 'Trimming...'
              : _state == AppState.sending
                  ? 'Sending...'
                  : 'CUT & SEND TO TELEGRAM',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canSend ? const Color(0xFF0088CC) : _kDim,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
