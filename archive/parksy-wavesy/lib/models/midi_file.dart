import 'dart:typed_data';

/// General MIDI instrument names (0-127)
const gmInstruments = [
  'Acoustic Grand Piano', 'Bright Acoustic Piano', 'Electric Grand Piano',
  'Honky-tonk Piano', 'Electric Piano 1', 'Electric Piano 2',
  'Harpsichord', 'Clavinet', 'Celesta', 'Glockenspiel', 'Music Box',
  'Vibraphone', 'Marimba', 'Xylophone', 'Tubular Bells', 'Dulcimer',
  'Drawbar Organ', 'Percussive Organ', 'Rock Organ', 'Church Organ',
  'Reed Organ', 'Accordion', 'Harmonica', 'Tango Accordion',
  'Acoustic Guitar (nylon)', 'Acoustic Guitar (steel)',
  'Electric Guitar (jazz)', 'Electric Guitar (clean)',
  'Electric Guitar (muted)', 'Overdriven Guitar', 'Distortion Guitar',
  'Guitar Harmonics', 'Acoustic Bass', 'Electric Bass (finger)',
  'Electric Bass (pick)', 'Fretless Bass', 'Slap Bass 1', 'Slap Bass 2',
  'Synth Bass 1', 'Synth Bass 2', 'Violin', 'Viola', 'Cello',
  'Contrabass', 'Tremolo Strings', 'Pizzicato Strings', 'Orchestral Harp',
  'Timpani', 'String Ensemble 1', 'String Ensemble 2', 'Synth Strings 1',
  'Synth Strings 2', 'Choir Aahs', 'Voice Oohs', 'Synth Choir',
  'Orchestra Hit', 'Trumpet', 'Trombone', 'Tuba', 'Muted Trumpet',
  'French Horn', 'Brass Section', 'Synth Brass 1', 'Synth Brass 2',
  'Soprano Sax', 'Alto Sax', 'Tenor Sax', 'Baritone Sax', 'Oboe',
  'English Horn', 'Bassoon', 'Clarinet', 'Piccolo', 'Flute', 'Recorder',
  'Pan Flute', 'Blown Bottle', 'Shakuhachi', 'Whistle', 'Ocarina',
  'Lead 1 (square)', 'Lead 2 (sawtooth)', 'Lead 3 (calliope)',
  'Lead 4 (chiff)', 'Lead 5 (charang)', 'Lead 6 (voice)',
  'Lead 7 (fifths)', 'Lead 8 (bass+lead)', 'Pad 1 (new age)',
  'Pad 2 (warm)', 'Pad 3 (polysynth)', 'Pad 4 (choir)', 'Pad 5 (bowed)',
  'Pad 6 (metallic)', 'Pad 7 (halo)', 'Pad 8 (sweep)', 'FX 1 (rain)',
  'FX 2 (soundtrack)', 'FX 3 (crystal)', 'FX 4 (atmosphere)',
  'FX 5 (brightness)', 'FX 6 (goblins)', 'FX 7 (echoes)', 'FX 8 (sci-fi)',
  'Sitar', 'Banjo', 'Shamisen', 'Koto', 'Kalimba', 'Bagpipe', 'Fiddle',
  'Shanai', 'Tinkle Bell', 'Agogo', 'Steel Drums', 'Woodblock',
  'Taiko Drum', 'Melodic Tom', 'Synth Drum', 'Reverse Cymbal',
  'Guitar Fret Noise', 'Breath Noise', 'Seashore', 'Bird Tweet',
  'Telephone Ring', 'Helicopter', 'Applause', 'Gunshot',
];

String gmInstrumentName(int program) {
  if (program < 0 || program >= gmInstruments.length) return 'Unknown';
  return gmInstruments[program];
}

// ---------------------------------------------------------------------------
// MIDI Event
// ---------------------------------------------------------------------------

class MidiEvent {
  int deltaTicks;
  int absoluteTick;
  final Uint8List data; // raw event bytes (status + data, no delta)

  MidiEvent(this.deltaTicks, this.absoluteTick, this.data);

  // --- Status detection ---
  int get statusByte => data.isNotEmpty ? data[0] : 0;
  int get command => statusByte & 0xF0;
  int get channel => statusByte & 0x0F;

  bool get isNoteOn =>
      command == 0x90 && data.length >= 3 && data[2] > 0;
  bool get isNoteOff =>
      command == 0x80 ||
      (command == 0x90 && data.length >= 3 && data[2] == 0);
  bool get isProgramChange => command == 0xC0 && data.length >= 2;
  bool get isControlChange => command == 0xB0 && data.length >= 3;
  bool get isMetaEvent => data.isNotEmpty && data[0] == 0xFF;
  bool get isSysEx =>
      data.isNotEmpty && (data[0] == 0xF0 || data[0] == 0xF7);

  bool get isTempo =>
      isMetaEvent && data.length >= 6 && data[1] == 0x51;
  bool get isTrackName =>
      isMetaEvent && data.length >= 3 && data[1] == 0x03;
  bool get isEndOfTrack =>
      isMetaEvent && data.length >= 3 && data[1] == 0x2F;
  bool get isTimeSignature =>
      isMetaEvent && data.length >= 3 && data[1] == 0x58;

  // --- Parsed values ---
  int? get note =>
      (command == 0x80 || command == 0x90) && data.length >= 3
          ? data[1]
          : null;
  int? get velocity =>
      (command == 0x80 || command == 0x90) && data.length >= 3
          ? data[2]
          : null;
  int? get program => isProgramChange ? data[1] : null;

  double? get tempoBpm {
    if (!isTempo) return null;
    final uspb = (data[3] << 16) | (data[4] << 8) | data[5];
    if (uspb == 0) return null;
    return 60000000.0 / uspb;
  }

  int? get tempoMicroseconds {
    if (!isTempo) return null;
    return (data[3] << 16) | (data[4] << 8) | data[5];
  }

  String? get trackName {
    if (!isTrackName) return null;
    // FF 03 <varlen> <text>
    int offset = 2;
    int len = 0;
    while (offset < data.length) {
      final b = data[offset++];
      len = (len << 7) | (b & 0x7F);
      if (b & 0x80 == 0) break;
    }
    if (offset + len > data.length) return null;
    return String.fromCharCodes(data.sublist(offset, offset + len));
  }

  // --- Factory methods ---
  MidiEvent copyWith({int? deltaTicks, int? absoluteTick}) {
    return MidiEvent(
      deltaTicks ?? this.deltaTicks,
      absoluteTick ?? this.absoluteTick,
      Uint8List.fromList(data),
    );
  }

  MidiEvent withProgram(int newProgram) {
    assert(isProgramChange);
    final newData = Uint8List.fromList(data);
    newData[1] = newProgram & 0x7F;
    return MidiEvent(deltaTicks, absoluteTick, newData);
  }

  static MidiEvent createTempo(int deltaTicks, int absoluteTick, double bpm) {
    final uspb = (60000000.0 / bpm).round().clamp(1, 0xFFFFFF);
    return MidiEvent(deltaTicks, absoluteTick, Uint8List.fromList([
      0xFF, 0x51, 0x03,
      (uspb >> 16) & 0xFF,
      (uspb >> 8) & 0xFF,
      uspb & 0xFF,
    ]));
  }

  static MidiEvent createProgramChange(
      int deltaTicks, int absoluteTick, int channel, int program) {
    return MidiEvent(deltaTicks, absoluteTick, Uint8List.fromList([
      0xC0 | (channel & 0x0F),
      program & 0x7F,
    ]));
  }

  static MidiEvent createEndOfTrack(int deltaTicks, int absoluteTick) {
    return MidiEvent(
        deltaTicks, absoluteTick, Uint8List.fromList([0xFF, 0x2F, 0x00]));
  }
}

// ---------------------------------------------------------------------------
// MIDI Track
// ---------------------------------------------------------------------------

class MidiTrack {
  List<MidiEvent> events;

  MidiTrack(this.events);

  String? get name {
    for (final e in events) {
      if (e.isTrackName) return e.trackName;
    }
    return null;
  }

  int? get primaryChannel {
    for (final e in events) {
      if (e.isNoteOn) return e.channel;
    }
    return null;
  }

  int? get primaryProgram {
    for (final e in events) {
      if (e.isProgramChange) return e.program;
    }
    return null;
  }

  int get noteCount => events.where((e) => e.isNoteOn).length;

  int get maxTick {
    if (events.isEmpty) return 0;
    return events.last.absoluteTick;
  }
}

// ---------------------------------------------------------------------------
// Tempo Map Entry
// ---------------------------------------------------------------------------

class TempoEntry {
  final int tick;
  final double microsecondsPerBeat;

  TempoEntry(this.tick, this.microsecondsPerBeat);

  double get bpm => 60000000.0 / microsecondsPerBeat;
}

// ---------------------------------------------------------------------------
// MIDI File
// ---------------------------------------------------------------------------

class MidiFile {
  int format;
  int ticksPerBeat;
  List<MidiTrack> tracks;

  MidiFile({
    required this.format,
    required this.ticksPerBeat,
    required this.tracks,
  });

  // --- Tempo map ---

  List<TempoEntry> get tempoMap {
    final entries = <TempoEntry>[];
    for (final track in tracks) {
      for (final event in track.events) {
        if (event.isTempo) {
          entries.add(TempoEntry(
            event.absoluteTick,
            event.tempoMicroseconds!.toDouble(),
          ));
        }
      }
    }
    entries.sort((a, b) => a.tick.compareTo(b.tick));
    if (entries.isEmpty) {
      entries.add(TempoEntry(0, 500000)); // default 120 BPM
    }
    return entries;
  }

  double get initialBpm => tempoMap.first.bpm;

  Duration tickToDuration(int tick) {
    final map = tempoMap;
    double microseconds = 0;
    int prevTick = 0;
    double uspb = map.first.microsecondsPerBeat;

    for (final entry in map) {
      if (entry.tick >= tick) break;
      if (entry.tick > prevTick) {
        microseconds += (entry.tick - prevTick) / ticksPerBeat * uspb;
        prevTick = entry.tick;
      }
      uspb = entry.microsecondsPerBeat;
    }
    microseconds += (tick - prevTick) / ticksPerBeat * uspb;
    return Duration(microseconds: microseconds.round());
  }

  int durationToTick(Duration d) {
    final targetUs = d.inMicroseconds.toDouble();
    final map = tempoMap;
    double microseconds = 0;
    int prevTick = 0;
    double uspb = map.first.microsecondsPerBeat;

    for (final entry in map) {
      final segmentUs =
          (entry.tick - prevTick) / ticksPerBeat * uspb;
      if (microseconds + segmentUs >= targetUs) {
        break;
      }
      microseconds += segmentUs;
      prevTick = entry.tick;
      uspb = entry.microsecondsPerBeat;
    }

    final remaining = targetUs - microseconds;
    final remainingTicks = (remaining / uspb * ticksPerBeat).round();
    return prevTick + remainingTicks;
  }

  Duration get duration {
    int maxTick = 0;
    for (final track in tracks) {
      final t = track.maxTick;
      if (t > maxTick) maxTick = t;
    }
    return tickToDuration(maxTick);
  }

  // --- Parse ---

  factory MidiFile.parse(Uint8List data) {
    if (data.length < 14) {
      return MidiFile(format: 0, ticksPerBeat: 480, tracks: []);
    }

    final headerTag = String.fromCharCodes(data.sublist(0, 4));
    if (headerTag != 'MThd') {
      return MidiFile(format: 0, ticksPerBeat: 480, tracks: []);
    }

    final headerLen = _readU32(data, 4);
    final format = _readU16(data, 8);
    final nTracks = _readU16(data, 10);
    int ticksPerBeat = _readU16(data, 12);
    if (ticksPerBeat == 0) ticksPerBeat = 480;

    final tracks = <MidiTrack>[];
    int offset = 8 + headerLen;

    for (int t = 0; t < nTracks && offset + 8 <= data.length; t++) {
      final trackTag = String.fromCharCodes(data.sublist(offset, offset + 4));
      if (trackTag != 'MTrk') break;
      final trackLen = _readU32(data, offset + 4);
      int pos = offset + 8;
      final trackEnd = (pos + trackLen).clamp(0, data.length);

      final events = <MidiEvent>[];
      int tickPos = 0;
      int runningStatus = 0;

      while (pos < trackEnd) {
        // Read delta time
        final deltaResult = _readVarLen(data, pos);
        final delta = deltaResult.$1;
        pos += deltaResult.$2;
        tickPos += delta;

        if (pos >= trackEnd) break;

        int status = data[pos];
        final eventStart = pos;

        // Running status
        if (status < 0x80) {
          status = runningStatus;
        } else {
          pos++;
          if (status >= 0x80 && status < 0xF0) {
            runningStatus = status;
          }
        }

        final cmd = status & 0xF0;
        Uint8List eventData;

        if (cmd == 0x80 || cmd == 0x90 || cmd == 0xA0 ||
            cmd == 0xB0 || cmd == 0xE0) {
          // 2 data bytes
          if (pos + 1 >= data.length) break;
          final d1 = data[pos++];
          final d2 = data[pos++];
          eventData = Uint8List.fromList([status, d1, d2]);
        } else if (cmd == 0xC0 || cmd == 0xD0) {
          // 1 data byte
          if (pos >= data.length) break;
          final d1 = data[pos++];
          eventData = Uint8List.fromList([status, d1]);
        } else if (status == 0xFF) {
          // Meta event
          if (pos >= data.length) break;
          final metaType = data[pos++];
          final lenResult = _readVarLen(data, pos);
          final metaLen = lenResult.$1;
          final lenBytes = lenResult.$2;
          pos += lenBytes;
          final metaEnd = (pos + metaLen).clamp(0, data.length);
          final metaData = data.sublist(pos, metaEnd);
          pos = metaEnd;

          // Build raw bytes: FF type varlen data
          final varLenBytes = _writeVarLen(metaLen);
          eventData = Uint8List.fromList([
            0xFF,
            metaType,
            ...varLenBytes,
            ...metaData,
          ]);
        } else if (status == 0xF0 || status == 0xF7) {
          // SysEx
          final lenResult = _readVarLen(data, pos);
          final sysLen = lenResult.$1;
          final lenBytes = lenResult.$2;
          pos += lenBytes;
          final sysEnd = (pos + sysLen).clamp(0, data.length);
          final sysData = data.sublist(pos, sysEnd);
          pos = sysEnd;

          final varLenBytes = _writeVarLen(sysLen);
          eventData = Uint8List.fromList([
            status,
            ...varLenBytes,
            ...sysData,
          ]);
        } else {
          // Unknown — skip one byte
          eventData = Uint8List.fromList([status]);
        }

        events.add(MidiEvent(delta, tickPos, eventData));
      }

      tracks.add(MidiTrack(events));
      offset = trackEnd;
    }

    return MidiFile(
      format: format,
      ticksPerBeat: ticksPerBeat,
      tracks: tracks,
    );
  }

  // --- Serialize ---

  Uint8List serialize() {
    final buffer = BytesBuilder();

    // Header: MThd
    buffer.add([0x4D, 0x54, 0x68, 0x64]); // "MThd"
    buffer.add(_writeU32(6)); // header length
    buffer.add(_writeU16(format));
    buffer.add(_writeU16(tracks.length));
    buffer.add(_writeU16(ticksPerBeat));

    // Tracks
    for (final track in tracks) {
      final trackBuffer = BytesBuilder();

      for (final event in track.events) {
        trackBuffer.add(_writeVarLen(event.deltaTicks));
        trackBuffer.add(event.data);
      }

      // Ensure end-of-track
      final hasEot = track.events.isNotEmpty && track.events.last.isEndOfTrack;
      if (!hasEot) {
        trackBuffer.add(_writeVarLen(0));
        trackBuffer.add([0xFF, 0x2F, 0x00]);
      }

      final trackBytes = trackBuffer.toBytes();
      buffer.add([0x4D, 0x54, 0x72, 0x6B]); // "MTrk"
      buffer.add(_writeU32(trackBytes.length));
      buffer.add(trackBytes);
    }

    return buffer.toBytes();
  }

  // --- Helpers ---

  static int _readU32(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  static int _readU16(Uint8List data, int offset) {
    return (data[offset] << 8) | data[offset + 1];
  }

  static (int, int) _readVarLen(Uint8List data, int offset) {
    int value = 0;
    int bytesRead = 0;
    while (offset < data.length) {
      final b = data[offset++];
      bytesRead++;
      value = (value << 7) | (b & 0x7F);
      if (b & 0x80 == 0) break;
    }
    return (value, bytesRead);
  }

  static List<int> _writeVarLen(int value) {
    if (value < 0) value = 0;
    if (value < 0x80) return [value];
    final bytes = <int>[];
    bytes.add(value & 0x7F);
    value >>= 7;
    while (value > 0) {
      bytes.insert(0, (value & 0x7F) | 0x80);
      value >>= 7;
    }
    return bytes;
  }

  static List<int> _writeU32(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  static List<int> _writeU16(int value) {
    return [
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}
