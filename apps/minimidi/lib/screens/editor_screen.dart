import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../audio/pcm_converter.dart';
import '../audio/yin_detector.dart';
import '../audio/pitch_post.dart';
import '../audio/midi_refiner.dart';
import '../midi/midi_writer.dart';
import '../midi/midi_audit_player.dart';

class EditorScreen extends StatefulWidget {
  final String path;
  const EditorScreen({super.key, required this.path});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _player = AudioPlayer();
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  Duration? _inPt;
  Duration? _outPt;
  int _preset = 120;
  bool _playing = false;
  bool _exporting = false;
  bool _exportingMidi = false;

  // MIDI preview state
  List<NoteEvent>? _midiPreview;
  String? _midiStatus;

  // Stage 2A/2B notes for audit
  List<NoteEvent>? _notes2A;
  List<NoteEvent>? _notes2B;

  // Stage 2B options
  bool _stage2bEnabled = true;
  bool _keySafeEnabled = false;
  int _detectedKeyRoot = 0;
  ScaleType _detectedScale = ScaleType.major;

  // Stage 2C: MIDI Audit Player
  final MidiAuditPlayer _auditPlayer = MidiAuditPlayer();
  bool _auditPlaying = false;
  bool _audit2B = true; // true = 2B, false = 2A
  bool _auditLoop = false;
  double _auditPos = 0;
  double _auditDur = 0;

  @override
  void initState() {
    super.initState();
    _init();
    _setupAuditListeners();
  }

  void _setupAuditListeners() {
    _auditPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _auditPos = pos);
    });
    _auditPlayer.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _auditPlaying = state == PlayerState.playing;
        });
      }
    });
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
    _auditPlayer.dispose();
    super.dispose();
  }

  void _markIn() {
    setState(() {
      _inPt = _pos;
      if (_outPt == null || _outPt! <= _inPt!) {
        _outPt = _inPt! + Duration(seconds: _preset);
        if (_outPt! > _dur) _outPt = _dur;
      }
      _clearMidiData();
    });
  }

  void _markOut() {
    setState(() {
      _outPt = _pos;
      if (_inPt == null || _inPt! >= _outPt!) {
        _inPt = _outPt! - Duration(seconds: _preset);
        if (_inPt!.isNegative) _inPt = Duration.zero;
      }
      _clearMidiData();
    });
  }

  void _clearMidiData() {
    _midiPreview = null;
    _notes2A = null;
    _notes2B = null;
    _auditPlayer.stop();
  }

  void _setPreset(int s) {
    setState(() {
      _preset = s;
      if (_inPt != null) {
        _outPt = _inPt! + Duration(seconds: s);
        if (_outPt! > _dur) _outPt = _dur;
      }
      _clearMidiData();
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtSec(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toInt().toString().padLeft(2, '0');
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

  Future<void> _exportMidi() async {
    if (_inPt == null || _outPt == null) return;
    setState(() {
      _exportingMidi = true;
      _midiStatus = 'Extracting audio...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final src = widget.path.split('/').last.split('.').first;
      final inS = _inPt!.inSeconds;
      final outS = _outPt!.inSeconds;

      final tempWav = '${dir.path}/temp_trim.wav';
      final dur = (_outPt! - _inPt!).inMilliseconds / 1000.0;

      final cmd = '-y -ss ${_inPt!.inMilliseconds / 1000} '
          '-i "${widget.path}" '
          '-t $dur '
          '-ar 44100 -ac 1 -c:a pcm_s16le '
          '"$tempWav"';

      await FFmpegKit.execute(cmd);

      setState(() => _midiStatus = 'Converting to PCM...');

      final samples = await PcmConverter.convertToMonoPcm(tempWav);
      if (samples == null) {
        throw Exception('Failed to convert audio to PCM');
      }

      setState(() => _midiStatus = 'Detecting pitch (YIN)...');

      final pitchFrames = YinDetector.detectPitch(samples);

      setState(() => _midiStatus = 'Stage 2A: Post-processing...');

      // Stage 2A
      final notes2A = PitchPostProcessor.process(pitchFrames);

      if (notes2A.isEmpty) {
        throw Exception('No melody detected in the selected region');
      }

      _notes2A = notes2A;

      // Stage 2B
      setState(() => _midiStatus = 'Stage 2B: Refining...');

      if (_keySafeEnabled) {
        final detected = MidiRefiner.detectKey(notes2A);
        _detectedKeyRoot = detected.$1;
        _detectedScale = detected.$2;
      }

      final options = RefineOptions(
        densityControl: true,
        rhythmSnap: true,
        snapResolution: SnapResolution.sixteenth,
        lengthNormalization: true,
        keySafe: _keySafeEnabled,
        keyRoot: _detectedKeyRoot,
        keyScale: _detectedScale,
      );

      final notes2B = MidiRefiner.refine(notes2A, options);
      _notes2B = notes2B;

      // Set preview based on current toggle
      final notes = _stage2bEnabled ? notes2B : notes2A;
      _midiPreview = notes;

      // Load into audit player
      _loadAuditNotes();

      setState(() => _midiStatus = 'Writing MIDI...');

      final suffix = _stage2bEnabled ? '_2B' : '_2A';
      final midiPath = '${dir.path}/${ts}_${src}_IN${inS}_OUT$outS$suffix.mid';
      final result = await MidiWriter.writeToFile(notes, midiPath);

      if (result == null) {
        throw Exception('Failed to write MIDI file');
      }

      setState(() {
        _exportingMidi = false;
        _midiStatus = null;
      });

      if (!mounted) return;

      final stageLabel = _stage2bEnabled ? '2B' : '2A';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('MIDI ($stageLabel): ${notes.length} notes exported'),
          duration: const Duration(seconds: 2),
        ),
      );
      await Share.shareXFiles([XFile(midiPath)]);
    } catch (e) {
      setState(() {
        _exportingMidi = false;
        _midiStatus = 'Error: $e';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('MIDI export failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _loadAuditNotes() {
    final notes = _audit2B ? _notes2B : _notes2A;
    if (notes != null && notes.isNotEmpty) {
      _auditPlayer.loadNotes(notes);
      _auditPlayer.setLoop(_auditLoop);
      _auditDur = _auditPlayer.totalDuration;
    }
  }

  void _toggleAuditVersion() {
    _auditPlayer.stop();
    setState(() {
      _audit2B = !_audit2B;
      _midiPreview = _audit2B ? _notes2B : _notes2A;
    });
    _loadAuditNotes();
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Position display
            Text(
              '${_fmt(_pos)} / ${_fmt(_dur)}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Scrubber
            Slider(
              value: _pos.inMilliseconds.toDouble(),
              max: _dur.inMilliseconds.toDouble().clamp(1, double.infinity),
              onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
            ),
            const SizedBox(height: 8),
            // Play/Pause
            IconButton(
              iconSize: 72,
              icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
              onPressed: () => _playing ? _player.pause() : _player.play(),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            // Clip duration
            if (_inPt != null && _outPt != null)
              Text('Clip: ${_fmt(clipDur)}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
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

            const SizedBox(height: 16),

            // Stage 2B Options Card
            _buildOptionsCard(),

            // MIDI Preview + Audit Player
            if (_midiPreview != null) ...[
              const SizedBox(height: 16),
              _buildMidiPreview(),
              const SizedBox(height: 12),
              _buildAuditPlayer(),
            ],

            // Status message
            if (_midiStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                _midiStatus!,
                style: TextStyle(
                  color: _midiStatus!.startsWith('Error') ? Colors.red : Colors.grey,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Export buttons
            if (_exporting || _exportingMidi)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_inPt != null && _outPt != null) ? _export : null,
                      icon: const Icon(Icons.audio_file, size: 24),
                      label: const Text('Export WAV', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_inPt != null && _outPt != null) ? _exportMidi : null,
                      icon: const Icon(Icons.piano, size: 24),
                      label: Text(
                        _stage2bEnabled ? 'Export MIDI (2B)' : 'Export MIDI (2A)',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Stage 2C: MIDI Audit Player UI
  Widget _buildAuditPlayer() {
    final hasNotes = (_notes2A != null && _notes2A!.isNotEmpty) ||
        (_notes2B != null && _notes2B!.isNotEmpty);

    if (!hasNotes) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.headphones, size: 18, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'MIDI Audit',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[200]),
              ),
              const Spacer(),
              // 2A/2B Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAuditToggleButton('2A', !_audit2B),
                    _buildAuditToggleButton('2B', _audit2B),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Position display
          Text(
            '${_fmtSec(_auditPos)} / ${_fmtSec(_auditDur)}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4),

          // Progress bar
          LinearProgressIndicator(
            value: _auditDur > 0 ? (_auditPos / _auditDur).clamp(0, 1) : 0,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation(Colors.teal),
          ),
          const SizedBox(height: 12),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Loop toggle
              IconButton(
                icon: Icon(
                  Icons.repeat,
                  color: _auditLoop ? Colors.teal : Colors.grey,
                ),
                onPressed: () {
                  setState(() => _auditLoop = !_auditLoop);
                  _auditPlayer.setLoop(_auditLoop);
                },
                tooltip: 'Loop',
              ),
              const SizedBox(width: 8),
              // Stop
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _auditPlayer.stop,
                tooltip: 'Stop',
              ),
              // Play/Pause
              IconButton(
                iconSize: 48,
                icon: Icon(
                  _auditPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.teal,
                ),
                onPressed: () {
                  if (_auditPlaying) {
                    _auditPlayer.pause();
                  } else {
                    _auditPlayer.play();
                  }
                },
              ),
              // Placeholder for symmetry
              const SizedBox(width: 48),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditToggleButton(String label, bool selected) {
    return GestureDetector(
      onTap: selected ? null : _toggleAuditVersion,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stage 2B: DAW-Ready', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Grid snap, density control, overlap fix',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
              Switch(
                value: _stage2bEnabled,
                onChanged: (v) => setState(() {
                  _stage2bEnabled = v;
                  _clearMidiData();
                }),
                activeColor: Colors.deepPurple,
              ),
            ],
          ),
          if (_stage2bEnabled) ...[
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Key-Safe', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        _keySafeEnabled && _midiPreview != null
                            ? 'Auto-detected: ${NoteNames.keyName(_detectedKeyRoot, _detectedScale)}'
                            : 'Snap to Major/Minor scale',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _keySafeEnabled,
                  onChanged: (v) => setState(() {
                    _keySafeEnabled = v;
                    _clearMidiData();
                  }),
                  activeColor: Colors.amber,
                ),
              ],
            ),
          ],
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        side: BorderSide(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value != null ? _fmt(value) : '--:--',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMidiPreview() {
    if (_midiPreview == null || _midiPreview!.isEmpty) return const SizedBox();

    final stats = PitchPostProcessor.getStats(_midiPreview!);
    final noteCount = stats['noteCount'] as int;
    final midiRange = stats['midiRange'] as List<int>;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.piano, size: 18, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                'MIDI Preview ${_audit2B ? "(2B)" : "(2A)"}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple[200]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Notes: $noteCount'),
          Text('Range: ${MidiWriter.midiNoteName(midiRange[0])} - ${MidiWriter.midiNoteName(midiRange[1])}'),
          if (_keySafeEnabled && _audit2B)
            Text('Key: ${NoteNames.keyName(_detectedKeyRoot, _detectedScale)}'),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: CustomPaint(
              size: const Size(double.infinity, 40),
              painter: _NotesPainter(
                notes: _midiPreview!,
                midiMin: midiRange[0],
                midiMax: midiRange[1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesPainter extends CustomPainter {
  final List<NoteEvent> notes;
  final int midiMin;
  final int midiMax;

  _NotesPainter({required this.notes, required this.midiMin, required this.midiMax});

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty) return;

    final paint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill;

    final totalDuration = notes.last.endTime;
    final midiSpan = (midiMax - midiMin).clamp(1, 128);

    for (final note in notes) {
      final x = (note.startTime / totalDuration) * size.width;
      final w = (note.duration / totalDuration) * size.width;
      final y = size.height - ((note.midiNote - midiMin) / midiSpan) * size.height - 4;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y.clamp(0, size.height - 4), w.clamp(2, size.width), 4),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NotesPainter oldDelegate) => notes != oldDelegate.notes;
}
