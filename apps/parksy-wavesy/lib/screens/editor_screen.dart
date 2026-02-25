import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/midi_service.dart';

class EditorScreen extends StatefulWidget {
  final String path;
  const EditorScreen({super.key, required this.path});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // Audio player (MP3/WAV/M4A)
  AudioPlayer? _player;
  // MIDI player
  MidiService? _midiService;

  bool get _isMidi {
    final lower = widget.path.toLowerCase();
    return lower.endsWith('.mid') || lower.endsWith('.midi');
  }

  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  Duration? _inPt;
  Duration? _outPt;
  int _preset = 120;
  bool _playing = false;
  bool _exporting = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (_isMidi) {
        await _initMidi();
      } else {
        await _initAudio();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _initAudio() async {
    _player = AudioPlayer();
    await _player!.setFilePath(widget.path);
    _dur = _player!.duration ?? Duration.zero;
    _player!.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player!.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
  }

  Future<void> _initMidi() async {
    _midiService = MidiService();
    _dur = await _midiService!.loadMidiFile(widget.path);
    _midiService!.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _midiService!.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    _midiService?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_isMidi) {
      _playing ? _midiService?.pause() : _midiService?.play();
    } else {
      _playing ? _player?.pause() : _player?.play();
    }
  }

  void _seek(Duration target) {
    if (_isMidi) {
      _midiService?.seek(target);
    } else {
      _player?.seek(target);
    }
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
    setState(() => _exporting = true);

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final src = widget.path.split('/').last.split('.').first;
    final inS = _inPt!.inSeconds;
    final outS = _outPt!.inSeconds;
    final out = '${dir.path}/${ts}_${src}_IN${inS}_OUT$outS.wav';
    final dur = (_outPt! - _inPt!).inMilliseconds / 1000.0;

    if (_isMidi) {
      // MIDI export: not supported in v3.0.0 — show message
      setState(() => _exporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MIDI export coming in v4.0 — use audio files for now'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Audio export via FFmpeg
    final cmd = '-y -ss ${_inPt!.inMilliseconds / 1000} '
        '-i "${widget.path}" '
        '-t $dur '
        '-af "afade=t=in:d=0.01,afade=t=out:st=${dur - 0.01}:d=0.01" '
        '-ar 44100 -ac 2 -c:a pcm_s16le '
        '"$out"';

    await FFmpegKit.execute(cmd);
    setState(() => _exporting = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: ${out.split('/').last}'),
        duration: const Duration(seconds: 2),
      ),
    );
    await Share.shareXFiles([XFile(out)]);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.path.split('/').last;
    final clipDur = (_inPt != null && _outPt != null)
        ? _outPt! - _inPt!
        : Duration.zero;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isMidi)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text('MIDI'),
                backgroundColor: Colors.teal.withOpacity(0.3),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Position display
                      Text(
                        '${_fmt(_pos)} / ${_fmt(_dur)}',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Scrubber
                      Slider(
                        value: _pos.inMilliseconds
                            .toDouble()
                            .clamp(0, _dur.inMilliseconds.toDouble()),
                        max: _dur.inMilliseconds
                            .toDouble()
                            .clamp(1, double.infinity),
                        onChanged: (v) =>
                            _seek(Duration(milliseconds: v.toInt())),
                      ),
                      const SizedBox(height: 8),
                      // Play/Pause
                      IconButton(
                        iconSize: 72,
                        icon: Icon(_playing
                            ? Icons.pause_circle
                            : Icons.play_circle),
                        onPressed: _togglePlay,
                      ),
                      const SizedBox(height: 24),
                      // IN/OUT buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMarkButton(
                            label: 'IN',
                            value: _inPt,
                            onTap: _markIn,
                            color: Colors.green,
                          ),
                          _buildMarkButton(
                            label: 'OUT',
                            value: _outPt,
                            onTap: _markOut,
                            color: Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Clip duration
                      if (_inPt != null && _outPt != null)
                        Text(
                          'Clip: ${_fmt(clipDur)}',
                          style: const TextStyle(fontSize: 18),
                        ),
                      const SizedBox(height: 16),
                      // Preset chips
                      Wrap(
                        spacing: 8,
                        children: [30, 60, 120, 180].map((s) {
                          return ChoiceChip(
                            label: Text('${s}s'),
                            selected: _preset == s,
                            onSelected: (_) => _setPreset(s),
                          );
                        }).toList(),
                      ),
                      const Spacer(),
                      // Export button
                      if (_exporting)
                        const CircularProgressIndicator()
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                (_inPt != null && _outPt != null) ? _export : null,
                            icon: Icon(
                              _isMidi ? Icons.piano : Icons.save_alt,
                              size: 28,
                            ),
                            label: Text(
                              _isMidi ? 'Export (v4.0)' : 'Export WAV',
                              style: const TextStyle(fontSize: 20),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMarkButton({
    required String label,
    required Duration? value,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        side: BorderSide(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value != null ? _fmt(value) : '--:--',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
