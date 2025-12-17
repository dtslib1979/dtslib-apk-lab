import 'dart:io';
import 'dart:typed_data';
import '../audio/pitch_post.dart';

/// Standard MIDI File writer
/// Outputs Format 0 (single track) MIDI file
class MidiWriter {
  // Fixed parameters as specified
  static const int tempo = 120; // BPM
  static const int ppq = 480; // Pulses per quarter note
  static const int velocity = 80;
  static const int channel = 0;

  // Microseconds per beat for tempo 120
  static const int microsecondsPerBeat = 500000; // 60,000,000 / 120

  /// Convert note events to MIDI file and save
  static Future<String?> writeToFile(
      List<NoteEvent> notes, String outputPath) async {
    if (notes.isEmpty) return null;

    try {
      final bytes = _buildMidiFile(notes);
      final file = File(outputPath);
      await file.writeAsBytes(bytes);
      return outputPath;
    } catch (e) {
      return null;
    }
  }

  /// Build complete MIDI file bytes
  static Uint8List _buildMidiFile(List<NoteEvent> notes) {
    final buffer = BytesBuilder();

    // Header chunk
    buffer.add(_buildHeaderChunk());

    // Track chunk
    buffer.add(_buildTrackChunk(notes));

    return buffer.toBytes();
  }

  /// Build MIDI header chunk (MThd)
  static Uint8List _buildHeaderChunk() {
    final buffer = BytesBuilder();

    // "MThd"
    buffer.add([0x4D, 0x54, 0x68, 0x64]);

    // Header length (6 bytes)
    buffer.add([0x00, 0x00, 0x00, 0x06]);

    // Format 0 (single track)
    buffer.add([0x00, 0x00]);

    // Number of tracks (1)
    buffer.add([0x00, 0x01]);

    // Time division (PPQ 480)
    buffer.add([(ppq >> 8) & 0xFF, ppq & 0xFF]);

    return buffer.toBytes();
  }

  /// Build MIDI track chunk (MTrk)
  static Uint8List _buildTrackChunk(List<NoteEvent> notes) {
    final trackData = BytesBuilder();

    // Tempo meta event at time 0
    trackData.add(_variableLengthQuantity(0)); // delta time
    trackData.add([0xFF, 0x51, 0x03]); // tempo meta event
    trackData.add([
      (microsecondsPerBeat >> 16) & 0xFF,
      (microsecondsPerBeat >> 8) & 0xFF,
      microsecondsPerBeat & 0xFF,
    ]);

    // Convert notes to MIDI events
    final events = _notesToMidiEvents(notes);

    // Sort events by absolute tick
    events.sort((a, b) => a.tick.compareTo(b.tick));

    // Write events with delta times
    int lastTick = 0;
    for (final event in events) {
      final deltaTick = event.tick - lastTick;
      trackData.add(_variableLengthQuantity(deltaTick));
      trackData.add(event.data);
      lastTick = event.tick;
    }

    // End of track
    trackData.add(_variableLengthQuantity(0));
    trackData.add([0xFF, 0x2F, 0x00]);

    // Build complete track chunk
    final trackBytes = trackData.toBytes();
    final buffer = BytesBuilder();

    // "MTrk"
    buffer.add([0x4D, 0x54, 0x72, 0x6B]);

    // Track length
    final length = trackBytes.length;
    buffer.add([
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
    ]);

    buffer.add(trackBytes);

    return buffer.toBytes();
  }

  /// Convert note events to MIDI note on/off events
  static List<_MidiEvent> _notesToMidiEvents(List<NoteEvent> notes) {
    final events = <_MidiEvent>[];

    for (final note in notes) {
      final startTick = _secondsToTicks(note.startTime);
      final endTick = _secondsToTicks(note.endTime);

      // Note On
      events.add(_MidiEvent(
        tick: startTick,
        data: [0x90 | channel, note.midiNote, velocity],
      ));

      // Note Off
      events.add(_MidiEvent(
        tick: endTick,
        data: [0x80 | channel, note.midiNote, 0],
      ));
    }

    return events;
  }

  /// Convert seconds to MIDI ticks
  static int _secondsToTicks(double seconds) {
    // ticks = seconds * (tempo/60) * ppq
    // At 120 BPM: ticks = seconds * 2 * 480 = seconds * 960
    return (seconds * (tempo / 60.0) * ppq).round();
  }

  /// Encode value as MIDI variable-length quantity
  static List<int> _variableLengthQuantity(int value) {
    if (value < 0) value = 0;

    final bytes = <int>[];
    bytes.add(value & 0x7F);
    value >>= 7;

    while (value > 0) {
      bytes.insert(0, (value & 0x7F) | 0x80);
      value >>= 7;
    }

    return bytes;
  }

  /// Get MIDI note name (for display)
  static String midiNoteName(int midi) {
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];
    final octave = (midi ~/ 12) - 1;
    final note = names[midi % 12];
    return '$note$octave';
  }
}

/// Internal MIDI event with absolute tick position
class _MidiEvent {
  final int tick;
  final List<int> data;

  _MidiEvent({required this.tick, required this.data});
}
