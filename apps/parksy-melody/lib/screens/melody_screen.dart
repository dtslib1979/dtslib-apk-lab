import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

const _botToken = '8669426963:AAGvsn8ZnWgkTccw2G2AqgxHbq9RVtmBZMA';
const _chatId   = '6858098283';

// ── Thief palette ───────────────────────────────────────────────
const _kBg      = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kCard    = Color(0xFF1C1C1C);
const _kRed     = Color(0xFFE53935);
const _kRedDim  = Color(0xFF4A1010);
const _kText    = Color(0xFFF5F5F5);
const _kMuted   = Color(0xFF666666);
const _kBorder  = Color(0xFF2A2A2A);
const _kGold    = Color(0xFFFFB300);

enum _State { idle, downloading, ready, trimming, sending, done }

class MelodyScreen extends StatefulWidget {
  const MelodyScreen({super.key});
  @override
  State<MelodyScreen> createState() => _MelodyScreenState();
}

class _MelodyScreenState extends State<MelodyScreen>
    with SingleTickerProviderStateMixin {
  static const _ch = MethodChannel('com.parksy.melody/intent');
  final _rng = Random();

  final _urlCtrl = TextEditingController();
  final _player  = AudioPlayer();
  late final AnimationController _pulseCtrl;

  _State _st   = _State.idle;
  String _msg  = '';
  double _prog = 0.0;
  String? _dlPath;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  int  _preset   = 30;
  bool _playing  = false;

  // ── 구간 지정 ──────────────────────────────────────────────────
  double _startSec = 0.0;
  double _endSec   = 0.0;       // 0 = 미설정 (프리셋 모드)
  bool   _pinMode  = false;     // true = 핀포인트 모드, false = 프리셋 모드

  // path_provider 기반 — Android 11+ 스코프드 스토리지 대응
  String _rawPath = '';
  String _outPath = '';

  static const _presets = [
    (label: '10s',   sec: 10),
    (label: '20s',   sec: 20),
    (label: '30s',   sec: 30),
    (label: '1 min', sec: 60),
    (label: '2 min', sec: 120),
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
    _initPaths();
    _loadSharedUrl();
  }

  Future<void> _initPaths() async {
    final tmp = await getTemporaryDirectory();
    if (mounted) {
      setState(() {
        _rawPath = '${tmp.path}/melody_raw.tmp';
        _outPath = '${tmp.path}/melody_dl.mp3';
      });
    }
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
      _st == _State.trimming    ||
      _st == _State.sending;

  // ── 핀포인트 설정 ──────────────────────────────────────────────
  void _setStart() {
    setState(() {
      _startSec = _pos.inMilliseconds / 1000.0;
      if (_endSec > 0 && _endSec <= _startSec) _endSec = 0.0;
      _msg = '📍 Start → ${_fmtSec(_startSec)}';
    });
  }

  void _setEnd() {
    final cur = _pos.inMilliseconds / 1000.0;
    if (cur <= _startSec) {
      setState(() => _msg = '❌ End must be after start');
      return;
    }
    setState(() {
      _endSec = cur;
      _msg = '📍 End → ${_fmtSec(_endSec)}  (${(_endSec - _startSec).toStringAsFixed(1)}s)';
    });
  }

  // ── Download ──────────────────────────────────────────────────
  Future<void> _download() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    if (_rawPath.isEmpty) await _initPaths(); // 경로 미초기화 방어

    setState(() {
      _st       = _State.downloading;
      _prog     = 0.05;
      _msg      = 'Getting stream URL...';
      _startSec = 0.0;
      _endSec   = 0.0;
    });

    await Permission.audio.request();
    await Permission.storage.request();
    await Permission.notification.request();

    // ForegroundService 시작 — 백그라운드 다운로드 유지
    try { await _ch.invokeMethod('startForeground'); } catch (_) {}

    try {
      final streamUrl =
          await _ch.invokeMethod<String>('getAudioUrl', {'url': url});
      if (streamUrl == null) throw Exception('No stream URL returned');

      setState(() { _prog = 0.1; _msg = 'Downloading audio...'; });

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(streamUrl));
        request.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 10)';
        final response = await client.send(request);
        final contentLength = response.contentLength ?? 0;

        final sink = File(_rawPath).openWrite();
        int downloaded = 0;
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (contentLength > 0 && mounted) {
            setState(() {
              _prog = 0.1 + 0.8 * (downloaded / contentLength);
              _msg  = 'Downloading... ${(downloaded / 1024 / 1024).toStringAsFixed(1)} MB';
            });
          }
        }
        await sink.close();
      } finally {
        client.close();
      }

      setState(() { _prog = 0.92; _msg = 'Converting to MP3...'; });

      final session = await FFmpegKit.execute(
          '-y -i "$_rawPath" -acodec libmp3lame -ab 192k "$_outPath"');
      if (!ReturnCode.isSuccess(await session.getReturnCode())) {
        await File(_rawPath).copy(_outPath);
      }

      setState(() { _prog = 0.97; _msg = 'Loading player...'; });
      await _player.setFilePath(_outPath);

      // ForegroundService 종료
      try { await _ch.invokeMethod('stopForeground'); } catch (_) {}

      setState(() {
        _dlPath = _outPath;
        _dur    = _player.duration ?? Duration.zero;
        _st     = _State.ready;
        _msg    = 'Stolen ✓  ${_fmt(_dur)}  |  seek → SET START/END → CUT';
        _prog   = 1.0;
      });
    } catch (e) {
      try { await _ch.invokeMethod('stopForeground'); } catch (_) {}
      setState(() { _st = _State.idle; _msg = 'ERR: $e'; });
    }
  }

  // ── Cut & Send ────────────────────────────────────────────────
  // 페이드아웃: 1.2 ~ 1.8s 랜덤 (자연스러운 루프/믹스 위해)
  double get _fadeOut => 1.2 + _rng.nextDouble() * 0.6;  // [1.2, 1.8)
  static const _fadeIn = 0.5;

  Future<void> _cutAndSend() async {
    if (_dlPath == null) return;

    final totalDur = _dur.inSeconds > 0 ? _dur.inSeconds : _preset;
    final maxStart = (totalDur - 1).clamp(0, totalDur).toDouble();
    final start    = _startSec.clamp(0.0, maxStart);

    // 핀포인트 모드: endSec로 구간, 프리셋 모드: preset 길이
    final double dur;
    if (_pinMode && _endSec > _startSec) {
      dur = (_endSec - start).clamp(1.0, (totalDur - start).toDouble());
    } else {
      dur = _preset.clamp(1, (totalDur - start.toInt()).clamp(1, _preset)).toDouble();
    }
    final fo      = _fadeOut;
    final foStart = (dur - fo).clamp(0.0, dur);

    setState(() {
      _st  = _State.trimming;
      _msg = 'Cutting ${_fmtSec(start)} → ${_fmtSec(start + dur)}  (${dur.toStringAsFixed(1)}s, fade out: ${fo.toStringAsFixed(1)}s)...';
    });
    await _player.stop();

    final tmp = await getTemporaryDirectory();
    final out = '${tmp.path}/cut_${dur.toInt()}s_${start.toInt()}s.mp3';

    final cmd = '-y -ss ${start.toStringAsFixed(3)} -t ${dur.toStringAsFixed(3)} '
        '-i "$_dlPath" '
        '-af "afade=t=in:st=0:d=$_fadeIn,'
        'afade=t=out:st=${foStart.toStringAsFixed(3)}:d=${fo.toStringAsFixed(3)}" '
        '-acodec libmp3lame -ab 192k "$out"';

    final session = await FFmpegKit.execute(cmd);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      setState(() { _st = _State.ready; _msg = 'Trim failed'; });
      return;
    }

    setState(() { _st = _State.sending; _msg = 'Saving + Sending...'; });
    try {
      // 로컬 저장: /sdcard/Download/Melody/
      final localDir = Directory('/sdcard/Download/Melody');
      if (!await localDir.exists()) await localDir.create(recursive: true);
      final localName = 'melody_${dur.toInt()}s_from${start.toInt()}s.mp3';
      final localPath = '${localDir.path}/$localName';
      await File(out).copy(localPath);

      // 텔레그램 전송
      final req = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.telegram.org/bot$_botToken/sendDocument'));
      req.fields['chat_id'] = _chatId;
      req.files.add(await http.MultipartFile.fromPath(
          'document', out, filename: localName));
      final res = await req.send();
      final tgOk = res.statusCode == 200;
      setState(() {
        _st  = _State.done;
        _msg = tgOk
            ? '✅ Saved + Sent  |  $localPath'
            : '⚠️ Saved locally  |  Telegram ${res.statusCode}';
      });
    } catch (e) {
      // 텔레그램 실패해도 로컬 저장은 시도
      setState(() { _st = _State.ready; _msg = 'Send error: $e'; });
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  String _fmtSec(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$sec';
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
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
                    _buildCutCard(),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _kMuted, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kRedDim,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _kRed.withOpacity(0.6), width: 1.5),
            ),
            child: const Center(child: Text('🥷', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('YOUTUBE 채집',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  )),
              Text('steal → trim → send',
                  style: TextStyle(
                    color: _kRed.withOpacity(0.7),
                    fontSize: 9,
                    letterSpacing: 1.2,
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
          _sectionLabel('TARGET URL'),
          const SizedBox(height: 10),
          TextField(
            controller: _urlCtrl,
            enabled: !_busy,
            style: const TextStyle(color: _kText, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'youtube.com/watch?v=...  또는 YouTube 공유',
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
    final isOk  = _st == _State.done && _msg.startsWith('✅');
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
                  : _kBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kRed),
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
    final startPct = _dur.inMilliseconds > 0
        ? (_startSec * 1000 / _dur.inMilliseconds).clamp(0.0, 1.0)
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
          // 시간 표시 + SET START 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_pos),
                  style: const TextStyle(
                      color: _kText, fontSize: 12, fontFamily: 'monospace')),
              GestureDetector(
                onTap: _busy ? null : _setStart,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _startSec > 0
                        ? _kGold.withOpacity(0.15)
                        : _kRedDim,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _startSec > 0
                          ? _kGold.withOpacity(0.6)
                          : _kRed.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag,
                          size: 12,
                          color: _startSec > 0 ? _kGold : _kRed),
                      const SizedBox(width: 4),
                      Text(
                        _startSec > 0
                            ? 'START: ${_fmtSec(_startSec)}'
                            : 'SET START',
                        style: TextStyle(
                          color: _startSec > 0 ? _kGold : _kRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(_fmt(_dur),
                  style: const TextStyle(
                      color: _kMuted, fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          // 슬라이더 + 스타트 마커
          Stack(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _kRed,
                  inactiveTrackColor: _kBorder,
                  thumbColor: _kRed,
                  overlayColor: _kRed.withOpacity(0.2),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: pct,
                  onChanged: _busy
                      ? null
                      : (v) => _player.seek(Duration(
                          milliseconds:
                              (v * _dur.inMilliseconds).round())),
                ),
              ),
              // 스타트 포인트 마커
              if (_startSec > 0 && _dur.inMilliseconds > 0)
                Positioned(
                  left: 12 + startPct * (MediaQuery.of(context).size.width - 32 - 24),
                  top: 14,
                  child: Container(
                    width: 2,
                    height: 20,
                    color: _kGold.withOpacity(0.8),
                  ),
                ),
              // 엔드 포인트 마커 (핀포인트 모드)
              if (_endSec > 0 && _dur.inMilliseconds > 0) ...[
                Builder(builder: (_) {
                  final endPct = (_endSec * 1000 / _dur.inMilliseconds).clamp(0.0, 1.0);
                  return Positioned(
                    left: 12 + endPct * (MediaQuery.of(context).size.width - 32 - 24),
                    top: 14,
                    child: Container(
                      width: 2,
                      height: 20,
                      color: _kRed.withOpacity(0.8),
                    ),
                  );
                }),
              ],
            ],
          ),
          // 컨트롤
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: _kMuted, size: 22),
                onPressed: _busy
                    ? null
                    : () => _player.seek(Duration(
                        seconds:
                            (_pos.inSeconds - 10).clamp(0, _dur.inSeconds))),
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
                  child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.forward_10, color: _kMuted, size: 22),
                onPressed: _busy
                    ? null
                    : () => _player.seek(Duration(
                        seconds:
                            (_pos.inSeconds + 10).clamp(0, _dur.inSeconds))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCutCard() {
    final pinEnd = _pinMode && _endSec > _startSec;
    final effectiveDur = pinEnd ? (_endSec - _startSec) : _preset.toDouble();
    final endSec = _startSec + effectiveDur;

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
          // 모드 토글
          Row(
            children: [
              _sectionLabel('CUT MODE'),
              const Spacer(),
              GestureDetector(
                onTap: _busy ? null : () => setState(() => _pinMode = !_pinMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _pinMode ? _kGold.withOpacity(0.15) : _kRedDim,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _pinMode ? _kGold.withOpacity(0.6) : _kRed.withOpacity(0.5)),
                  ),
                  child: Text(
                    _pinMode ? 'PINPOINT' : 'PRESET',
                    style: TextStyle(
                      color: _pinMode ? _kGold : _kRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 프리셋 모드: 칩 선택
          if (!_pinMode) ...[
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
          ],

          // 핀포인트 모드: SET END 버튼
          if (_pinMode) ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _busy ? null : _setEnd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _endSec > 0 ? _kGold.withOpacity(0.12) : _kBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _endSec > 0 ? _kGold.withOpacity(0.5) : _kBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flag, size: 14,
                              color: _endSec > 0 ? _kGold : _kMuted),
                          const SizedBox(width: 6),
                          Text(
                            _endSec > 0
                                ? 'END: ${_fmtSec(_endSec)}'
                                : 'SET END (seek → tap)',
                            style: TextStyle(
                              color: _endSec > 0 ? _kGold : _kMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_endSec > 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _endSec = 0.0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Icon(Icons.close, color: _kMuted, size: 16),
                    ),
                  ),
                ],
              ],
            ),
            if (!pinEnd)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Seek to end position, then tap SET END',
                  style: TextStyle(color: _kMuted.withOpacity(0.7), fontSize: 10),
                ),
              ),
          ],

          const SizedBox(height: 12),
          // 컷 범위 + 페이드 정보
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoChip('START', _fmtSec(_startSec),
                        _startSec > 0 ? _kGold : _kMuted),
                    const Icon(Icons.arrow_forward, color: _kMuted, size: 14),
                    _infoChip('END', _fmtSec(endSec),
                        pinEnd ? _kGold : _kText),
                    const Icon(Icons.arrow_forward, color: _kMuted, size: 14),
                    _infoChip('DUR', '${effectiveDur.toStringAsFixed(1)}s', _kRed),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.graphic_eq, color: _kMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'fade in: ${_fadeIn}s  |  fade out: 1.2~1.8s (random)',
                      style: const TextStyle(color: _kMuted, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: _kMuted, fontSize: 9, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
      ],
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

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4, height: 14,
          decoration: BoxDecoration(
            color: _kRed, borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
              color: _kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            )),
      ],
    );
  }
}
