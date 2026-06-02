import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/midi_service.dart';
import '../services/midi_editor.dart';
import '../models/midi_file.dart';

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
  // MIDI file model (for editing)
  MidiFile? _midiFile;

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

  // MIDI editing state
  List<TrackInfo> _tracks = [];
  double _bpm = 120;
  double _originalBpm = 120;
  bool _bpmChanged = false;
  Map<int, int> _instrumentChanges = {};
  int _transpose = 0;
  bool _showTracks = false;

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
    // Load for playback
    _midiService = MidiService();
    _dur = await _midiService!.loadMidiFile(widget.path);
    _midiService!.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _midiService!.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });

    // Load for editing
    final bytes = await File(widget.path).readAsBytes();
    _midiFile = MidiFile.parse(bytes);
    _tracks = MidiEditor.getTrackInfo(_midiFile!);
    _bpm = _midiFile!.initialBpm;
    _originalBpm = _bpm;
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

    if (_isMidi) {
      await _exportMidi(dir, ts, src, inS, outS);
    } else {
      await _exportAudio(dir, ts, src, inS, outS);
    }

    setState(() => _exporting = false);
  }

  Future<void> _exportMidi(
      Directory dir, String ts, String src, int inS, int outS) async {
    if (_midiFile == null) return;

    // Collect selected track indices
    final keepIndices = <int>{};
    for (final t in _tracks) {
      if (t.selected) keepIndices.add(t.index);
    }

    // Apply all edits
    final edited = MidiEditor.applyEdits(
      source: _midiFile!,
      trimStart: _inPt,
      trimEnd: _outPt,
      keepTrackIndices: keepIndices.length < _tracks.length ? keepIndices : null,
      newBpm: _bpmChanged ? _bpm : null,
      instrumentChanges: _instrumentChanges.isNotEmpty ? _instrumentChanges : null,
      transposeSemitones: _transpose != 0 ? _transpose : null,
    );

    // Serialize and save
    final outPath = '${dir.path}/${ts}_${src}_IN${inS}_OUT$outS.mid';
    final bytes = edited.serialize();
    await File(outPath).writeAsBytes(bytes);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: ${outPath.split('/').last}'),
        duration: const Duration(seconds: 2),
      ),
    );
    await Share.shareXFiles([XFile(outPath)]);
  }

  Future<void> _exportAudio(
      Directory dir, String ts, String src, int inS, int outS) async {
    final dur = (_outPt! - _inPt!).inMilliseconds / 1000.0;
    final out = '${dir.path}/${ts}_${src}_IN${inS}_OUT$outS.wav';
    final cmd = '-y -ss ${_inPt!.inMilliseconds / 1000} '
        '-i "${widget.path}" '
        '-t $dur '
        '-af "afade=t=in:d=0.01,afade=t=out:st=${dur - 0.01}:d=0.01" '
        '-ar 44100 -ac 2 -c:a pcm_s16le '
        '"$out"';

    await FFmpegKit.execute(cmd);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: ${out.split('/').last}'),
        duration: const Duration(seconds: 2),
      ),
    );
    await Share.shareXFiles([XFile(out)]);
  }

  void _showInstrumentPicker(TrackInfo track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2332),
      builder: (ctx) {
        return ListView.builder(
          itemCount: gmInstruments.length,
          itemBuilder: (_, i) {
            final selected = (_instrumentChanges[track.index] ?? track.program) == i;
            return ListTile(
              leading: selected
                  ? const Icon(Icons.check, color: Colors.tealAccent)
                  : const SizedBox(width: 24),
              title: Text(
                '$i: ${gmInstruments[i]}',
                style: TextStyle(
                  color: selected ? Colors.tealAccent : Colors.white70,
                  fontSize: 14,
                ),
              ),
              dense: true,
              onTap: () {
                setState(() {
                  _instrumentChanges[track.index] = i;
                });
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.path.split('/').last;
    final clipDur = (_inPt != null && _outPt != null)
        ? _outPt! - _inPt!
        : Duration.zero;

    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
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
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center),
                  ),
                )
              : SingleChildScrollView(
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
                        Text('Clip: ${_fmt(clipDur)}',
                            style: const TextStyle(fontSize: 18)),
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

                      // --- MIDI Editing Section ---
                      if (_isMidi && _midiFile != null) ...[
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),

                        // BPM Control
                        _buildBpmControl(),
                        const SizedBox(height: 16),

                        // Transpose Control
                        _buildTransposeControl(),
                        const SizedBox(height: 16),

                        // Track Panel
                        _buildTrackPanel(),
                      ],

                      const SizedBox(height: 24),
                      // Export button
                      if (_exporting)
                        const CircularProgressIndicator()
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_inPt != null && _outPt != null)
                                ? _export
                                : null,
                            icon: Icon(
                              _isMidi ? Icons.piano : Icons.save_alt,
                              size: 28,
                            ),
                            label: Text(
                              _isMidi ? 'Export MIDI' : 'Export WAV',
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

  // --- Transpose Control ---
  Widget _buildTransposeControl() {
    final label = transposeLabels[_transpose] ?? '${_transpose > 0 ? "+" : ""}$_transpose';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transpose',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _transpose != 0 ? Colors.amberAccent : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  setState(() => _transpose = (_transpose - 1).clamp(-12, 12));
                },
              ),
              Expanded(
                child: Slider(
                  value: _transpose.toDouble(),
                  min: -12,
                  max: 12,
                  divisions: 24,
                  onChanged: (v) {
                    setState(() => _transpose = v.round());
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  setState(() => _transpose = (_transpose + 1).clamp(-12, 12));
                },
              ),
            ],
          ),
          if (_transpose != 0)
            TextButton(
              onPressed: () => setState(() => _transpose = 0),
              child: const Text('Reset', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // --- BPM Control ---
  Widget _buildBpmControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tempo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                '${_bpm.round()} BPM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bpmChanged ? Colors.tealAccent : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  setState(() {
                    _bpm = (_bpm - 5).clamp(20, 300);
                    _bpmChanged = _bpm != _originalBpm;
                  });
                },
              ),
              Expanded(
                child: Slider(
                  value: _bpm,
                  min: 20,
                  max: 300,
                  onChanged: (v) {
                    setState(() {
                      _bpm = v;
                      _bpmChanged = _bpm.round() != _originalBpm.round();
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  setState(() {
                    _bpm = (_bpm + 5).clamp(20, 300);
                    _bpmChanged = _bpm != _originalBpm;
                  });
                },
              ),
            ],
          ),
          if (_bpmChanged)
            TextButton(
              onPressed: () {
                setState(() {
                  _bpm = _originalBpm;
                  _bpmChanged = false;
                });
              },
              child: Text('Reset (${_originalBpm.round()} BPM)',
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // --- Track Panel ---
  Widget _buildTrackPanel() {
    final activeTracks = _tracks.where((t) => t.noteCount > 0).toList();
    final emptyTracks = _tracks.where((t) => t.noteCount == 0).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _showTracks = !_showTracks),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tracks (${_tracks.where((t) => t.selected).length}/${_tracks.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Icon(_showTracks
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),

          if (_showTracks) ...[
            // Select all / none
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final t in _tracks) {
                          t.selected = true;
                        }
                      });
                    },
                    child: const Text('All', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final t in _tracks) {
                          t.selected = t.noteCount == 0; // keep meta tracks
                        }
                      });
                    },
                    child: const Text('None', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Active tracks (with notes)
            ...activeTracks.map((t) => _buildTrackTile(t)),

            // Empty tracks (meta-only)
            if (emptyTracks.isNotEmpty) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Meta tracks',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.4)),
                ),
              ),
              ...emptyTracks.map((t) => _buildTrackTile(t, isMeta: true)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTrackTile(TrackInfo track, {bool isMeta = false}) {
    final instrument = _instrumentChanges.containsKey(track.index)
        ? gmInstrumentName(_instrumentChanges[track.index]!)
        : track.instrumentName;
    final changed = _instrumentChanges.containsKey(track.index);

    return CheckboxListTile(
      dense: true,
      value: track.selected,
      onChanged: (v) => setState(() => track.selected = v ?? true),
      title: Row(
        children: [
          Expanded(
            child: Text(
              track.displayName,
              style: TextStyle(
                fontSize: 14,
                color: track.selected ? Colors.white : Colors.white38,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMeta && track.channel != 9)
            GestureDetector(
              onTap: () => _showInstrumentPicker(track),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: changed ? Colors.tealAccent : Colors.white24,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  instrument,
                  style: TextStyle(
                    fontSize: 11,
                    color: changed ? Colors.tealAccent : Colors.white54,
                  ),
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        isMeta
            ? 'Ch ${track.channel ?? "-"}'
            : '${track.noteCount} notes  Ch ${track.channel ?? "-"}',
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withOpacity(0.3),
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
            style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
