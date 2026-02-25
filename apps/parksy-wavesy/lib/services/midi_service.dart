import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:path_provider/path_provider.dart';

/// MIDI playback service wrapping flutter_midi_pro (FluidSynth).
///
/// Handles SoundFont loading, MIDI file parsing, and timed playback.
/// For v3.0.0: play/pause/seek on MIDI files with bundled SoundFont.
class MidiService {
  final MidiPro _midi = MidiPro();
  bool _sfLoaded = false;
  bool _playing = false;
  Timer? _ticker;

  // Parsed MIDI state
  List<_MidiEvent> _events = [];
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

    // Copy asset to temp file (flutter_midi_pro needs file path)
    final dir = await getApplicationDocumentsDirectory();
    final sfPath = '${dir.path}/default_soundfont.sf2';
    final sfFile = File(sfPath);

    if (!sfFile.existsSync()) {
      final data = await rootBundle.load('assets/soundfonts/TimGM6mb.sf2');
      await sfFile.writeAsBytes(data.buffer.asUint8List());
    }

    await _midi.loadSoundfont(sf2Path: sfPath, bank: 0, program: 0);
    _sfLoaded = true;
  }

  /// Parse a MIDI file and prepare for playback.
  /// Returns the total duration.
  Future<Duration> loadMidiFile(String path) async {
    await loadSoundFont();

    final bytes = await File(path).readAsBytes();
    _events = _parseMidi(bytes);
    _eventIndex = 0;
    _position = Duration.zero;
    _duration = _events.isNotEmpty
        ? _events.last.time
        : Duration.zero;

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
    // Stop all sounding notes
    _allNotesOff();
  }

  /// Seek to a position.
  void seek(Duration target) {
    _position = target;
    _positionCtrl.add(_position);

    // Find the right event index
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

    // Fire MIDI events up to current position
    while (_eventIndex < _events.length &&
        _events[_eventIndex].time <= _position) {
      final e = _events[_eventIndex];
      if (e.type == _MidiEventType.noteOn) {
        _midi.playNote(channel: e.channel, key: e.note, velocity: e.velocity);
      } else if (e.type == _MidiEventType.noteOff) {
        _midi.stopNote(channel: e.channel, key: e.note);
      }
      _eventIndex++;
    }

    // End of file
    if (_position >= _duration) {
      pause();
      _position = _duration;
      _positionCtrl.add(_position);
    }
  }

  void _allNotesOff() {
    for (int ch = 0; ch < 16; ch++) {
      for (int note = 0; note < 128; note++) {
        _midi.stopNote(channel: ch, key: note);
      }
    }
  }

  void dispose() {
    pause();
    _positionCtrl.close();
    _playingCtrl.close();
  }

  // ---- Minimal MIDI parser (Standard MIDI File format 0/1) ----

  List<_MidiEvent> _parseMidi(Uint8List data) {
    final events = <_MidiEvent>[];
    if (data.length < 14) return events;

    // Read header
    final headerTag = String.fromCharCodes(data.sublist(0, 4));
    if (headerTag != 'MThd') return events;

    final headerLen = _readU32(data, 4);
    final format = _readU16(data, 8);
    final nTracks = _readU16(data, 10);
    int ticksPerBeat = _readU16(data, 12);
    if (ticksPerBeat == 0) ticksPerBeat = 480;

    // Parse tracks
    int offset = 8 + headerLen;
    double microsecondsPerBeat = 500000; // default 120 BPM

    for (int t = 0; t < nTracks && offset < data.length - 8; t++) {
      final trackTag = String.fromCharCodes(data.sublist(offset, offset + 4));
      if (trackTag != 'MTrk') break;
      final trackLen = _readU32(data, offset + 4);
      int pos = offset + 8;
      final trackEnd = pos + trackLen;
      int tickPos = 0;
      int runningStatus = 0;

      while (pos < trackEnd && pos < data.length) {
        // Read variable-length delta time
        int delta = 0;
        while (pos < data.length) {
          final b = data[pos++];
          delta = (delta << 7) | (b & 0x7F);
          if (b & 0x80 == 0) break;
        }
        tickPos += delta;

        if (pos >= data.length) break;
        int status = data[pos];

        // Handle running status
        if (status < 0x80) {
          status = runningStatus;
        } else {
          pos++;
          if (status >= 0x80 && status < 0xF0) {
            runningStatus = status;
          }
        }

        final cmd = status & 0xF0;
        final ch = status & 0x0F;

        if (cmd == 0x90 && pos + 1 < data.length) {
          // Note On
          final note = data[pos++];
          final vel = data[pos++];
          final microseconds = (tickPos / ticksPerBeat) * microsecondsPerBeat;
          final time = Duration(microseconds: microseconds.toInt());
          if (vel > 0) {
            events.add(_MidiEvent(_MidiEventType.noteOn, time, ch, note, vel));
          } else {
            events.add(_MidiEvent(_MidiEventType.noteOff, time, ch, note, 0));
          }
        } else if (cmd == 0x80 && pos + 1 < data.length) {
          // Note Off
          final note = data[pos++];
          pos++; // velocity (ignored)
          final microseconds = (tickPos / ticksPerBeat) * microsecondsPerBeat;
          final time = Duration(microseconds: microseconds.toInt());
          events.add(_MidiEvent(_MidiEventType.noteOff, time, ch, note, 0));
        } else if (cmd == 0xA0 && pos + 1 < data.length) {
          pos += 2; // Aftertouch
        } else if (cmd == 0xB0 && pos + 1 < data.length) {
          pos += 2; // Control Change
        } else if (cmd == 0xC0) {
          pos++; // Program Change
        } else if (cmd == 0xD0) {
          pos++; // Channel Pressure
        } else if (cmd == 0xE0 && pos + 1 < data.length) {
          pos += 2; // Pitch Bend
        } else if (status == 0xFF && pos + 1 < data.length) {
          // Meta event
          final metaType = data[pos++];
          int metaLen = 0;
          while (pos < data.length) {
            final b = data[pos++];
            metaLen = (metaLen << 7) | (b & 0x7F);
            if (b & 0x80 == 0) break;
          }
          if (metaType == 0x51 && metaLen == 3 && pos + 2 < data.length) {
            // Tempo change
            microsecondsPerBeat =
                ((data[pos] << 16) | (data[pos + 1] << 8) | data[pos + 2])
                    .toDouble();
          }
          pos += metaLen;
        } else if (status == 0xF0 || status == 0xF7) {
          // SysEx
          int sysLen = 0;
          while (pos < data.length) {
            final b = data[pos++];
            sysLen = (sysLen << 7) | (b & 0x7F);
            if (b & 0x80 == 0) break;
          }
          pos += sysLen;
        }
      }

      offset = trackEnd;
    }

    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  int _readU32(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  int _readU16(Uint8List data, int offset) {
    return (data[offset] << 8) | data[offset + 1];
  }
}

enum _MidiEventType { noteOn, noteOff }

class _MidiEvent {
  final _MidiEventType type;
  final Duration time;
  final int channel;
  final int note;
  final int velocity;

  _MidiEvent(this.type, this.time, this.channel, this.note, this.velocity);
}
