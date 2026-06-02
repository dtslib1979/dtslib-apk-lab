import 'dart:typed_data';
import '../models/midi_file.dart';

/// Track metadata for display
class TrackInfo {
  final int index;
  final String? name;
  final int? channel;
  final int? program;
  final String instrumentName;
  final int noteCount;
  bool selected;

  TrackInfo({
    required this.index,
    this.name,
    this.channel,
    this.program,
    required this.instrumentName,
    required this.noteCount,
    this.selected = true,
  });

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (channel == 9) return 'Drums';
    return instrumentName;
  }
}

/// MIDI editing operations — all return new MidiFile (immutable pattern)
class MidiEditor {
  /// Extract track info for display
  static List<TrackInfo> getTrackInfo(MidiFile file) {
    final infos = <TrackInfo>[];
    for (int i = 0; i < file.tracks.length; i++) {
      final track = file.tracks[i];
      final program = track.primaryProgram;
      final channel = track.primaryChannel;
      infos.add(TrackInfo(
        index: i,
        name: track.name,
        channel: channel,
        program: program,
        instrumentName: channel == 9
            ? 'Drums'
            : (program != null ? gmInstrumentName(program) : 'Unknown'),
        noteCount: track.noteCount,
      ));
    }
    return infos;
  }

  /// Trim MIDI file to a time range
  static MidiFile trim(MidiFile file, Duration start, Duration end) {
    final startTick = file.durationToTick(start);
    final endTick = file.durationToTick(end);

    final newTracks = <MidiTrack>[];

    for (final track in file.tracks) {
      final newEvents = <MidiEvent>[];
      int prevTick = 0;

      // Collect program changes and other setup events before startTick
      final setupEvents = <MidiEvent>[];
      for (final e in track.events) {
        if (e.absoluteTick >= startTick) break;
        if (e.isProgramChange || e.isControlChange ||
            e.isTrackName || e.isTimeSignature || e.isTempo) {
          setupEvents.add(e);
        }
      }

      // Add setup events at tick 0
      for (final e in setupEvents) {
        newEvents.add(MidiEvent(
          prevTick == 0 ? 0 : 0,
          0,
          Uint8List.fromList(e.data),
        ));
      }

      // Add events within range
      for (final e in track.events) {
        if (e.absoluteTick < startTick) continue;
        if (e.absoluteTick > endTick) break;
        if (e.isEndOfTrack) continue; // we'll add our own

        final adjustedTick = e.absoluteTick - startTick;
        final delta = adjustedTick - prevTick;
        newEvents.add(MidiEvent(
          delta < 0 ? 0 : delta,
          adjustedTick,
          Uint8List.fromList(e.data),
        ));
        prevTick = adjustedTick;
      }

      // End of track
      final finalTick = endTick - startTick;
      final eotDelta = finalTick - prevTick;
      newEvents.add(MidiEvent.createEndOfTrack(
        eotDelta < 0 ? 0 : eotDelta,
        finalTick,
      ));

      newTracks.add(MidiTrack(newEvents));
    }

    return MidiFile(
      format: file.format,
      ticksPerBeat: file.ticksPerBeat,
      tracks: newTracks,
    );
  }

  /// Remove tracks by index set. Returns new file with remaining tracks.
  static MidiFile removeTracks(MidiFile file, Set<int> removeIndices) {
    final newTracks = <MidiTrack>[];
    for (int i = 0; i < file.tracks.length; i++) {
      if (!removeIndices.contains(i)) {
        newTracks.add(file.tracks[i]);
      }
    }

    // Keep at least the tempo track (track 0 in format 1)
    if (newTracks.isEmpty && file.tracks.isNotEmpty) {
      newTracks.add(file.tracks[0]);
    }

    return MidiFile(
      format: file.format,
      ticksPerBeat: file.ticksPerBeat,
      tracks: newTracks,
    );
  }

  /// Keep only selected tracks
  static MidiFile keepTracks(MidiFile file, Set<int> keepIndices) {
    final removeIndices = <int>{};
    for (int i = 0; i < file.tracks.length; i++) {
      if (!keepIndices.contains(i)) {
        removeIndices.add(i);
      }
    }
    return removeTracks(file, removeIndices);
  }

  /// Change tempo (replaces all tempo events with a single one)
  static MidiFile changeTempo(MidiFile file, double bpm) {
    final newTracks = <MidiTrack>[];

    for (int i = 0; i < file.tracks.length; i++) {
      final track = file.tracks[i];
      final newEvents = <MidiEvent>[];
      bool tempoSet = false;

      for (final e in track.events) {
        if (e.isTempo) {
          if (!tempoSet) {
            // Replace first tempo with new BPM
            newEvents.add(MidiEvent.createTempo(
              e.deltaTicks,
              e.absoluteTick,
              bpm,
            ));
            tempoSet = true;
          }
          // Skip subsequent tempo events
          continue;
        }
        newEvents.add(e.copyWith());
      }

      // If this is track 0 and no tempo was set, add one at the beginning
      if (i == 0 && !tempoSet) {
        newEvents.insert(0, MidiEvent.createTempo(0, 0, bpm));
      }

      newTracks.add(MidiTrack(newEvents));
    }

    return MidiFile(
      format: file.format,
      ticksPerBeat: file.ticksPerBeat,
      tracks: newTracks,
    );
  }

  /// Change instrument (program change) for a specific track
  static MidiFile changeInstrument(
      MidiFile file, int trackIndex, int newProgram) {
    if (trackIndex < 0 || trackIndex >= file.tracks.length) return file;

    final newTracks = <MidiTrack>[];

    for (int i = 0; i < file.tracks.length; i++) {
      if (i != trackIndex) {
        newTracks.add(file.tracks[i]);
        continue;
      }

      final track = file.tracks[i];
      final newEvents = <MidiEvent>[];
      bool programSet = false;

      for (final e in track.events) {
        if (e.isProgramChange) {
          // Replace program change with new instrument
          newEvents.add(e.withProgram(newProgram));
          programSet = true;
        } else {
          newEvents.add(e.copyWith());
        }
      }

      // If no program change existed, insert one at the beginning
      if (!programSet) {
        final channel = track.primaryChannel ?? 0;
        newEvents.insert(
          0,
          MidiEvent.createProgramChange(0, 0, channel, newProgram),
        );
      }

      newTracks.add(MidiTrack(newEvents));
    }

    return MidiFile(
      format: file.format,
      ticksPerBeat: file.ticksPerBeat,
      tracks: newTracks,
    );
  }

  /// Transpose all notes by semitones. Channel 9 (drums) is excluded.
  static MidiFile transpose(MidiFile file, int semitones) {
    if (semitones == 0) return file;

    final newTracks = <MidiTrack>[];

    for (final track in file.tracks) {
      final newEvents = <MidiEvent>[];

      for (final e in track.events) {
        if ((e.isNoteOn || e.isNoteOff) && e.channel != 9) {
          // Transpose note, clamp to 0-127
          final oldNote = e.data[1];
          final newNote = (oldNote + semitones).clamp(0, 127);
          final newData = Uint8List.fromList(e.data);
          newData[1] = newNote;
          newEvents.add(MidiEvent(e.deltaTicks, e.absoluteTick, newData));
        } else {
          newEvents.add(e.copyWith());
        }
      }

      newTracks.add(MidiTrack(newEvents));
    }

    return MidiFile(
      format: file.format,
      ticksPerBeat: file.ticksPerBeat,
      tracks: newTracks,
    );
  }

  /// Apply all edits and export
  static MidiFile applyEdits({
    required MidiFile source,
    Duration? trimStart,
    Duration? trimEnd,
    Set<int>? keepTrackIndices,
    double? newBpm,
    Map<int, int>? instrumentChanges,
    int? transposeSemitones,
  }) {
    var result = source;

    // 1. Apply instrument changes first (before track removal)
    if (instrumentChanges != null) {
      for (final entry in instrumentChanges.entries) {
        result = changeInstrument(result, entry.key, entry.value);
      }
    }

    // 2. Apply tempo change
    if (newBpm != null) {
      result = changeTempo(result, newBpm);
    }

    // 3. Transpose
    if (transposeSemitones != null && transposeSemitones != 0) {
      result = transpose(result, transposeSemitones);
    }

    // 4. Remove unselected tracks
    if (keepTrackIndices != null) {
      result = keepTracks(result, keepTrackIndices);
    }

    // 5. Trim
    if (trimStart != null && trimEnd != null) {
      result = trim(result, trimStart, trimEnd);
    }

    return result;
  }
}

/// Key signature labels for transposition display
const transposeLabels = {
  -12: '-1 Oct',
  -11: '-11 (Db)',
  -10: '-10 (D)',
  -9: '-9 (Eb)',
  -8: '-8 (E)',
  -7: '-7 (F)',
  -6: '-6 (F#)',
  -5: '-5 (G)',
  -4: '-4 (Ab)',
  -3: '-3 (A)',
  -2: '-2 (Bb)',
  -1: '-1 (B)',
  0: 'Original',
  1: '+1 (C#)',
  2: '+2 (D)',
  3: '+3 (Eb)',
  4: '+4 (E)',
  5: '+5 (F)',
  6: '+6 (F#)',
  7: '+7 (G)',
  8: '+8 (Ab)',
  9: '+9 (A)',
  10: '+10 (Bb)',
  11: '+11 (B)',
  12: '+1 Oct',
};
