import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _botToken = '8669426963:AAGvsn8ZnWgkTccw2G2AqgxHbq9RVtmBZMA';
const _chatId = '6858098283';

// ── Thief palette ──────────────────────────────────────────────
const _kBg      = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kCard    = Color(0xFF1C1C1C);
const _kRed     = Color(0xFFE53935);
const _kRedDim  = Color(0xFF4A1010);
const _kText    = Color(0xFFF5F5F5);
const _kMuted   = Color(0xFF666666);
const _kBorder  = Color(0xFF2A2A2A);

enum _State { idle, downloading, ready, trimming, sending, done }

class MelodyScreen extends StatefulWidget {
  const MelodyScreen({super.key});
  @override
  State<MelodyScreen> createState() => _MelodyScreenState();
}

class _MelodyScreenState extends State<MelodyScreen>
    with SingleTickerProviderStateMixin {
  static const _ch = MethodChannel('com.parksy.melody/intent');

  final _urlCtrl = TextEditingController();
  final _player  = AudioPlayer();
  late final AnimationController _pulseCtrl;

  _State _st = _State.idle;
  String _msg = '';
  double _prog = 0.0;
  String? _dlPath;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  int _preset = 30;
  bool _playing = false;

  static const _presets = [
    (label: '10s',   sec: 10),
    (label: '20s',   sec: 20),
    (label: '30s',   sec: 30),
    (label: '1 min', sec: 60),
    (label: '3 min', sec: 180),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _playing = s.playing);
    });
    _loadSharedUrl();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _player.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSharedUrl() async {
    try {
      final url = await _ch.invokeMethod<String>('getSharedUrl');
      if (url != null && url.isNotEmpty && mounted) {
        _urlCtrl.text = url;
        setState(() => _msg = '📎 YouTube URL received');
      }
    } catch (_) {}
  }

  bool get _busy =>
      _st == _State.downloading ||
      _st == _State.trimming ||
      _st == _State.sending;

  // ── Download ─────────────────────────────────────────────────
  static const _outPath = '/sdcard/Music/melody_dl.m4a';

  Future<void> _download() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() { _st = _State.downloading; _prog = 0; _msg = 'Analyzing...'; });

    await Permission.audio.request();
    await Permission.storage.request();

    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final audioInfo = manifest.audioOnly.withHighestBitrate();
      final totalBytes = audioInfo.size.totalBytes;

      setState(() => _msg = '🎵 ${video.title}');

      final outFile = File(_outPath);
      final sink = outFile.openWrite();
      final stream = yt.videos.streamsClient.get(audioInfo);
      int downloaded = 0;

      await for (final chunk in stream) {
        if (!mounted) { await sink.close(); return; }
        sink.add(chunk);
        downloaded += chunk.length;
        setState(() {
          _prog = (downloaded / totalBytes * 0.95).clamp(0.0, 0.95);
          _msg = 'Stealing... ${(downloaded / 1024 / 1024).toStringAsFixed(1)} / '
              '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
        });
      }
      await sink.flush();
      await sink.close();

      await _player.setFilePath(_outPath);
      setState(() {
        _dlPath = _outPath;
        _dur = _player.duration ?? Duration.zero;
        _st = _State.ready;
        _msg = 'Stolen ✓  ${_fmt(_dur)}';
        _prog = 1.0;
      });
    } catch (e) {
      setState(() { _st = _State.idle; _msg = 'ERR: $e'; });
    } finally {
      yt.close();
    }
  }

  // ── Cut & Send ────────────────────────────────────────────────
  Future<void> _cutAndSend() async {
    if (_dlPath == null) return;
    final end = _preset.clamp(1, _dur.inSeconds > 0 ? _dur.inSeconds : _preset);

    setState(() { _st = _State.trimming; _msg = 'Cutting 0–${end}s...'; });
    await _player.stop();

    final tmp = await getTemporaryDirectory();
    final out = '${tmp.path}/cut_${end}s.mp3';

    final session = await FFmpegKit.execute(
        '-y -i "$_dlPath" -t $end -acodec libmp3lame -ab 192k "$out"');
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      setState(() { _st = _State.ready; _msg = 'Trim failed'; });
      return;
    }

    setState(() { _st = _State.sending; _msg = 'Sending to Telegram...'; });
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('https://api.telegram.org/bot$_botToken/sendDocument'));
      req.fields['chat_id'] = _chatId;
      req.files.add(await http.MultipartFile.fromPath(
          'document', out, filename: 'melody_${end}s.mp3'));
      final res = await req.send();
      setState(() {
        _st = _State.done;
        _msg = res.statusCode == 200 ? '✅ Sent to @parksy_bridges_bot' : '❌ Telegram ${res.statusCode}';
      });
    } catch (e) {
      setState(() { _st = _State.ready; _msg = 'Send error: $e'; });
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildUrlCard(),
                  const SizedBox(height: 12),
                  if (_msg.isNotEmpty) _buildStatusRow(),
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    _buildProgressBar(),
                  ],
                  if (_st == _State.ready ||
                      _st == _State.trimming ||
                      _st == _State.sending ||
                      _st == _State.done) ...[
                    const SizedBox(height: 12),
                    _buildPlayer(),
                    const SizedBox(height: 12),
                    _buildPresets(),
                    const SizedBox(height: 16),
                    _buildSendBtn(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kRedDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kRed.withOpacity(0.6), width: 1.5),
            ),
            child: const Center(
              child: Text('🥷', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MELODY',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  )),
              Text('YouTube Audio Stealer',
                  style: TextStyle(
                    color: _kRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
          const Spacer(),
          if (_busy)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kRed.withOpacity(0.4 + 0.6 * _pulseCtrl.value),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUrlCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4, height: 14,
              decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text('TARGET URL',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _urlCtrl,
            enabled: !_busy,
            style: const TextStyle(color: _kText, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'youtube.com/watch?v=... or share from YouTube',
              hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
              filled: true,
              fillColor: _kBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kRed),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _urlCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: _kMuted, size: 16),
                      onPressed: () => setState(() => _urlCtrl.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: (_busy ||
                      _urlCtrl.text.trim().isEmpty ||
                      _st == _State.done)
                  ? null
                  : _download,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kRedDim,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                _st == _State.downloading ? 'STEALING...' : 'STEAL AUDIO',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    final isOk = _st == _State.done && _msg.startsWith('✅');
    final isErr = _st == _State.idle && _msg.startsWith('ERR:');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isOk
                ? Colors.green.withOpacity(0.4)
                : isErr
                    ? Colors.red.withOpacity(0.5)
                    : _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kRed,
                ),
              ),
            ),
          if (_busy) const SizedBox(width: 10),
          Expanded(
            child: Text(_msg,
                style: TextStyle(
                  color: isOk
                      ? Colors.greenAccent
                      : isErr
                          ? Colors.red[300]
                          : _kText,
                  fontSize: isErr ? 10 : 12,
                  fontFamily: isErr ? 'monospace' : null,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: _prog,
            backgroundColor: _kBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(_kRed),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(_prog * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: _kMuted, fontSize: 10)),
        ),
      ],
    );
  }

  Widget _buildPlayer() {
    final pct = _dur.inMilliseconds > 0
        ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_pos),
                  style: const TextStyle(color: _kText, fontSize: 12,
                      fontFamily: 'monospace')),
              Text(_fmt(_dur),
                  style: const TextStyle(color: _kMuted, fontSize: 12,
                      fontFamily: 'monospace')),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kRed,
              inactiveTrackColor: _kBorder,
              thumbColor: _kRed,
              overlayColor: _kRed.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              trackHeight: 2,
            ),
            child: Slider(
              value: pct,
              onChanged: _busy
                  ? null
                  : (v) => _player.seek(Duration(
                      milliseconds: (v * _dur.inMilliseconds).round())),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: _kMuted, size: 22),
                onPressed: _busy
                    ? null
                    : () => _player.seek(Duration(
                        seconds: (_pos.inSeconds - 10)
                            .clamp(0, _dur.inSeconds))),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _busy
                    ? null
                    : () => _playing ? _player.pause() : _player.play(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _busy ? _kRedDim : _kRed,
                    boxShadow: _busy
                        ? null
                        : [BoxShadow(color: _kRed.withOpacity(0.4), blurRadius: 12)],
                  ),
                  child: Icon(
                    _playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.forward_10, color: _kMuted, size: 22),
                onPressed: _busy
                    ? null
                    : () => _player.seek(Duration(
                        seconds: (_pos.inSeconds + 10)
                            .clamp(0, _dur.inSeconds))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4, height: 14,
              decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text('CUT LENGTH',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final sel = _preset == p.sec;
              return GestureDetector(
                onTap: _busy ? null : () => setState(() => _preset = p.sec),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? _kRed : _kBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: sel ? _kRed : _kBorder, width: 1),
                  ),
                  child: Text(p.label,
                      style: TextStyle(
                        color: sel ? Colors.white : _kMuted,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 13,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text('Cut: 0:00 → ${_fmt(Duration(seconds: _preset))}',
              style: const TextStyle(color: _kMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSendBtn() {
    final can = _st == _State.ready || _st == _State.done;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: can ? _cutAndSend : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: can ? const Color(0xFF0088CC) : _kCard,
          foregroundColor: Colors.white,
          disabledForegroundColor: _kMuted,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send, size: 16),
            const SizedBox(width: 8),
            Text(
              _st == _State.trimming
                  ? 'CUTTING...'
                  : _st == _State.sending
                      ? 'SENDING...'
                      : 'CUT & SEND TO TELEGRAM',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
