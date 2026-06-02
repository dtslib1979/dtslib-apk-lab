import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class TrimmerEditor extends StatefulWidget {
  final String path;
  const TrimmerEditor({super.key, required this.path});

  @override
  State<TrimmerEditor> createState() => _TrimmerEditorState();
}

class _TrimmerEditorState extends State<TrimmerEditor> {
  final _player = AudioPlayer();
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  Duration? _inPt;
  Duration? _outPt;
  int _preset = 120;
  bool _playing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _player.setFilePath(widget.path);
    _dur = _player.duration ?? Duration.zero;
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    setState(() {});
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _markIn() {
    setState(() {
      _inPt = _pos;
      if (_outPt == null || _outPt! <= _inPt!) {
        _outPt = _inPt! + Duration(seconds: _preset);
        if (_outPt! > _dur) _outPt = _dur;
      }
    });
  }

  void _markOut() {
    setState(() {
      _outPt = _pos;
      if (_inPt == null || _inPt! >= _outPt!) {
        _inPt = _outPt! - Duration(seconds: _preset);
        if (_inPt!.isNegative) _inPt = Duration.zero;
      }
    });
  }

  void _setPreset(int s) {
    setState(() {
      _preset = s;
      if (_inPt != null) {
        _outPt = _inPt! + Duration(seconds: s);
        if (_outPt! > _dur) _outPt = _dur;
      }
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _export() async {
    if (_inPt == null || _outPt == null) return;
    setState(() => _busy = true);

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final src = widget.path.split('/').last.split('.').first;
    final inS = _inPt!.inSeconds;
    final outS = _outPt!.inSeconds;
    final out = '${dir.path}/${ts}_${src}_IN${inS}_OUT$outS.wav';
    final dur = (_outPt! - _inPt!).inMilliseconds / 1000.0;

    final cmd = '-y -ss ${_inPt!.inMilliseconds / 1000} '
        '-i "${widget.path}" -t $dur '
        '-af "afade=t=in:d=0.01,afade=t=out:st=${dur - 0.01}:d=0.01" '
        '-ar 44100 -ac 2 -c:a pcm_s16le "$out"';

    await FFmpegKit.execute(cmd);
    setState(() => _busy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: ${out.split('/').last}')),
    );
    await Share.shareXFiles([XFile(out)]);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.path.split('/').last;
    final clip = (_inPt != null && _outPt != null) ? _outPt! - _inPt! : Duration.zero;

    return Scaffold(
      appBar: AppBar(title: Text(name, overflow: TextOverflow.ellipsis)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('${_fmt(_pos)} / ${_fmt(_dur)}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Slider(
              value: _pos.inMilliseconds.toDouble(),
              max: _dur.inMilliseconds.toDouble().clamp(1, double.infinity),
              onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
            ),
            IconButton(
              iconSize: 72,
              icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
              onPressed: () => _playing ? _player.pause() : _player.play(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _markBtn('IN', _inPt, _markIn, Colors.green),
                _markBtn('OUT', _outPt, _markOut, Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            if (_inPt != null && _outPt != null)
              Text('Clip: ${_fmt(clip)}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [30, 60, 120, 180].map((s) => ChoiceChip(
                label: Text('${s}s'),
                selected: _preset == s,
                onSelected: (_) => _setPreset(s),
              )).toList(),
            ),
            const Spacer(),
            if (_busy)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_inPt != null && _outPt != null) ? _export : null,
                  icon: const Icon(Icons.save_alt, size: 28),
                  label: const Text('Export WAV', style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _markBtn(String label, Duration? val, VoidCallback tap, Color c) {
    return ElevatedButton(
      onPressed: tap,
      style: ElevatedButton.styleFrom(
        backgroundColor: c.withOpacity(0.2),
        foregroundColor: c,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        side: BorderSide(color: c, width: 2),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(val != null ? _fmt(val) : '--:--',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
