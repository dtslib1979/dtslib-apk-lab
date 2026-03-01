import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:path_provider/path_provider.dart';
import '../models/midi_file.dart';

/// MIDI playback service wrapping flutter_midi_pro (FluidSynth).
///
/// Uses MidiFile model for parsing, flutter_midi_pro for audio output.
class MidiService {
  final MidiPro _midi = MidiPro();
  int _sfId = 0;
  bool _sfLoaded = false;
  bool _playing = false;
  Timer? _ticker;

  // Parsed MIDI state (from MidiFile model)
  List<_PlayEvent> _events = [];
  int _eventIndex = 0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  DateTime? _playStartTime;
  Duration _playStartOffset = Duration.zero;

  // Stream controllers
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();

  Stream<Duration> get positionStream => _positionCtrl.stream;
  Stream<bool> get playingStream => _playingCtrl.stream;
  Duration get duration => _duration;
  bool get isPlaying => _playing;

  /// Load the bundled SoundFont from assets.
  Future<void> loadSoundFont() async {
    if (_sfLoaded) return;

    final dir = await getApplicationDocumentsDirectory();
    final sfPath = '${dir.path}/default_soundfont.sf2';
    final sfFile = File(sfPath);

    if (!sfFile.existsSync()) {
      final data = await rootBundle.load('assets/soundfonts/TimGM6mb.sf2');
      await sfFile.writeAsBytes(data.buffer.asUint8List());
    }

    _sfId = await _midi.loadSoundfontFile(
        filePath: sfPath, bank: 0, program: 0);
    _sfLoaded = true;
  }

  /// Parse a MIDI file using MidiFile model and prepare for playback.
  Future<Duration> loadMidiFile(String path) async {
    await loadSoundFont();

    final bytes = await File(path).readAsBytes();
    final midiFile = MidiFile.parse(bytes);

    // Extract playback events from model
    _events = [];
    for (final track in midiFile.tracks) {
      for (final event in track.events) {
        if (event.isNoteOn) {
          final time = midiFile.tickToDuration(event.absoluteTick);
          _events.add(_PlayEvent(
            type: _PlayType.noteOn,
            time: time,
            channel: event.channel,
            note: event.note!,
            velocity: event.velocity!,
          ));
        } else if (event.isNoteOff) {
          final time = midiFile.tickToDuration(event.absoluteTick);
          _events.add(_PlayEvent(
            type: _PlayType.noteOff,
            time: time,
            channel: event.channel,
            note: event.note!,
            velocity: 0,
          ));
        } else if (event.isProgramChange) {
          final time = midiFile.tickToDuration(event.absoluteTick);
          _events.add(_PlayEvent(
            type: _PlayType.programChange,
            time: time,
            channel: event.channel,
            note: event.program!,
            velocity: 0,
          ));
        }
      }
    }

    _events.sort((a, b) => a.time.compareTo(b.time));
    _eventIndex = 0;
    _position = Duration.zero;
    _duration = midiFile.duration;

    return _duration;
  }

  /// Start or resume playback.
  void play() {
    if (_playing || _events.isEmpty) return;
    _playing = true;
    _playingCtrl.add(true);
    _playStartTime = DateTime.now();
    _playStartOffset = _position;

    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _tick();
    });
  }

  /// Pause playback.
  void pause() {
    if (!_playing) return;
    _playing = false;
    _playingCtrl.add(false);
    _ticker?.cancel();
    _ticker = null;
    _allNotesOff();
  }

  /// Seek to a position.
  void seek(Duration target) {
    _position = target;
    _positionCtrl.add(_position);

    _eventIndex = 0;
    for (int i = 0; i < _events.length; i++) {
      if (_events[i].time > target) break;
      _eventIndex = i;
    }

    if (_playing) {
      _playStartTime = DateTime.now();
      _playStartOffset = target;
    }
  }

  void _tick() {
    if (!_playing || _playStartTime == null) return;

    final elapsed = DateTime.now().difference(_playStartTime!);
    _position = _playStartOffset + elapsed;
    _positionCtrl.add(_position);

    while (_eventIndex < _events.length &&
        _events[_eventIndex].time <= _position) {
      final e = _events[_eventIndex];
      switch (e.type) {
        case _PlayType.noteOn:
          _midi.playNote(
              sfId: _sfId,
              channel: e.channel,
              key: e.note,
              velocity: e.velocity);
          break;
        case _PlayType.noteOff:
          _midi.stopNote(
              sfId: _sfId, channel: e.channel, key: e.note);
          break;
        case _PlayType.programChange:
          // flutter_midi_pro handles program changes via SoundFont
          break;
      }
      _eventIndex++;
    }

    if (_position >= _duration) {
      pause();
      _position = _duration;
      _positionCtrl.add(_position);
    }
  }

  void _allNotesOff() {
    _midi.stopAllNotes(sfId: _sfId);
  }

  void dispose() {
    pause();
    _positionCtrl.close();
    _playingCtrl.close();
  }
}

enum _PlayType { noteOn, noteOff, programChange }

class _PlayEvent {
  final _PlayType type;
  final Duration time;
  final int channel;
  final int note;
  final int velocity;

  _PlayEvent({
    required this.type,
    required this.time,
    required this.channel,
    required this.note,
    required this.velocity,
  });
}
