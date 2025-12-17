import 'dart:math' as math;
import 'pitch_post.dart';

/// Stage 2B: Production-ready MIDI post-processing
/// Makes MIDI usable in Cubase/Kontakt with minimal editing
class MidiRefiner {
  // Tempo 120 BPM timing
  static const double bpm = 120.0;
  static const double beatDuration = 60.0 / bpm; // 0.5 sec
  static const double eighthNote = beatDuration / 2; // 0.25 sec
  static const double sixteenthNote = beatDuration / 4; // 0.125 sec

  // Gap before next note to prevent overlap
  static const double epsilon = 0.01; // 10ms

  /// Apply all Stage 2B refinements
  /// [notes] - input from Stage 2A
  /// [options] - refinement options
  static List<NoteEvent> refine(List<NoteEvent> notes, RefineOptions options) {
    if (notes.isEmpty) return notes;

    var result = List<NoteEvent>.from(notes);

    // 1. Note Density Control (always on in 2B)
    if (options.densityControl) {
      result = _applyDensityControl(result);
    }

    // 2. Rhythm Snap
    if (options.rhythmSnap) {
      result = _applyRhythmSnap(result, options.snapResolution);
    }

    // 3. Key-Safe (optional, before length normalization)
    if (options.keySafe) {
      result = _applyKeySafe(result, options.keyRoot, options.keyScale);
    }

    // 4. Note Length Normalization (always on in 2B)
    if (options.lengthNormalization) {
      result = _applyLengthNormalization(result);
    }

    return result;
  }

  /// 1. Note Density Control
  /// - Merge notes shorter than 16th note
  /// - Merge rapid consecutive notes on same pitch
  static List<NoteEvent> _applyDensityControl(List<NoteEvent> notes) {
    if (notes.isEmpty) return notes;

    final result = <NoteEvent>[];
    NoteEvent? pending;

    for (final note in notes) {
      if (pending == null) {
        pending = note;
        continue;
      }

      // Check if notes should be merged
      final gap = note.startTime - pending.endTime;
      final samePitch = note.midiNote == pending.midiNote;
      final tooShort = pending.duration < sixteenthNote;
      final rapidSuccession = gap < sixteenthNote && samePitch;

      if (tooShort || rapidSuccession) {
        // Merge: extend pending to include current note
        pending = NoteEvent(
          startTime: pending.startTime,
          duration: note.endTime - pending.startTime,
          midiNote: pending.midiNote, // keep first pitch
        );
      } else {
        // Commit pending and start new
        if (pending.duration >= sixteenthNote) {
          result.add(pending);
        }
        pending = note;
      }
    }

    // Don't forget last note
    if (pending != null && pending.duration >= sixteenthNote) {
      result.add(pending);
    }

    return result;
  }

  /// 2. Rhythm Snap
  /// Snap note start times to nearest grid (8th or 16th)
  static List<NoteEvent> _applyRhythmSnap(
      List<NoteEvent> notes, SnapResolution resolution) {
    final gridSize =
        resolution == SnapResolution.eighth ? eighthNote : sixteenthNote;

    return notes.map((note) {
      final snappedStart = _snapToGrid(note.startTime, gridSize);
      return NoteEvent(
        startTime: snappedStart,
        duration: note.duration,
        midiNote: note.midiNote,
      );
    }).toList();
  }

  /// Snap time to nearest grid point
  static double _snapToGrid(double time, double gridSize) {
    return (time / gridSize).round() * gridSize;
  }

  /// 3. Note Length Normalization
  /// Set each note's duration to (next note start - epsilon)
  /// Prevents overlap
  static List<NoteEvent> _applyLengthNormalization(List<NoteEvent> notes) {
    if (notes.length < 2) return notes;

    final result = <NoteEvent>[];

    for (int i = 0; i < notes.length - 1; i++) {
      final current = notes[i];
      final next = notes[i + 1];

      // Duration = gap to next note - epsilon
      var newDuration = next.startTime - current.startTime - epsilon;

      // Minimum duration: 16th note
      newDuration = math.max(newDuration, sixteenthNote);

      // Don't extend beyond original if it would cause overlap
      if (current.startTime + newDuration > next.startTime) {
        newDuration = next.startTime - current.startTime - epsilon;
      }

      result.add(NoteEvent(
        startTime: current.startTime,
        duration: newDuration,
        midiNote: current.midiNote,
      ));
    }

    // Last note keeps original duration
    result.add(notes.last);

    return result;
  }

  /// 4. Key-Safe: Snap to nearest scale degree
  static List<NoteEvent> _applyKeySafe(
      List<NoteEvent> notes, int keyRoot, ScaleType scale) {
    final scaleNotes = _getScaleNotes(keyRoot, scale);

    return notes.map((note) {
      final snappedMidi = _snapToScale(note.midiNote, scaleNotes);
      return NoteEvent(
        startTime: note.startTime,
        duration: note.duration,
        midiNote: snappedMidi,
      );
    }).toList();
  }

  /// Get MIDI note numbers for a scale (all octaves)
  static Set<int> _getScaleNotes(int root, ScaleType scale) {
    // Intervals from root
    final intervals = scale == ScaleType.major
        ? [0, 2, 4, 5, 7, 9, 11] // Major scale
        : [0, 2, 3, 5, 7, 8, 10]; // Natural minor

    final notes = <int>{};
    for (int octave = 0; octave < 11; octave++) {
      for (final interval in intervals) {
        final midi = (octave * 12) + root + interval;
        if (midi >= 0 && midi <= 127) {
          notes.add(midi);
        }
      }
    }
    return notes;
  }

  /// Snap MIDI note to nearest scale degree
  static int _snapToScale(int midi, Set<int> scaleNotes) {
    if (scaleNotes.contains(midi)) return midi;

    // Find nearest scale note
    int nearest = midi;
    int minDist = 127;

    for (final scaleNote in scaleNotes) {
      final dist = (midi - scaleNote).abs();
      if (dist < minDist) {
        minDist = dist;
        nearest = scaleNote;
      }
    }

    // Clamp to valid range
    return nearest.clamp(36, 84);
  }

  /// Detect most likely key from notes (simple heuristic)
  static (int, ScaleType) detectKey(List<NoteEvent> notes) {
    if (notes.isEmpty) return (0, ScaleType.major); // C Major default

    // Count pitch classes
    final pitchCounts = List<int>.filled(12, 0);
    for (final note in notes) {
      pitchCounts[note.midiNote % 12]++;
    }

    // Try each key and scale, find best match
    int bestRoot = 0;
    ScaleType bestScale = ScaleType.major;
    int bestScore = 0;

    for (int root = 0; root < 12; root++) {
      for (final scale in ScaleType.values) {
        final intervals = scale == ScaleType.major
            ? [0, 2, 4, 5, 7, 9, 11]
            : [0, 2, 3, 5, 7, 8, 10];

        int score = 0;
        for (final interval in intervals) {
          score += pitchCounts[(root + interval) % 12];
        }

        if (score > bestScore) {
          bestScore = score;
          bestRoot = root;
          bestScale = scale;
        }
      }
    }

    return (bestRoot, bestScale);
  }
}

/// Refinement options for Stage 2B
class RefineOptions {
  final bool densityControl;
  final bool rhythmSnap;
  final SnapResolution snapResolution;
  final bool lengthNormalization;
  final bool keySafe;
  final int keyRoot; // 0-11 (C=0, C#=1, ...)
  final ScaleType keyScale;

  const RefineOptions({
    this.densityControl = true,
    this.rhythmSnap = true,
    this.snapResolution = SnapResolution.sixteenth,
    this.lengthNormalization = true,
    this.keySafe = false, // default OFF
    this.keyRoot = 0,
    this.keyScale = ScaleType.major,
  });

  /// Default Stage 2B options (all on except key-safe)
  static const stage2b = RefineOptions(
    densityControl: true,
    rhythmSnap: true,
    snapResolution: SnapResolution.sixteenth,
    lengthNormalization: true,
    keySafe: false,
  );

  /// Stage 2A only (no refinements)
  static const stage2aOnly = RefineOptions(
    densityControl: false,
    rhythmSnap: false,
    lengthNormalization: false,
    keySafe: false,
  );

  RefineOptions copyWith({
    bool? densityControl,
    bool? rhythmSnap,
    SnapResolution? snapResolution,
    bool? lengthNormalization,
    bool? keySafe,
    int? keyRoot,
    ScaleType? keyScale,
  }) {
    return RefineOptions(
      densityControl: densityControl ?? this.densityControl,
      rhythmSnap: rhythmSnap ?? this.rhythmSnap,
      snapResolution: snapResolution ?? this.snapResolution,
      lengthNormalization: lengthNormalization ?? this.lengthNormalization,
      keySafe: keySafe ?? this.keySafe,
      keyRoot: keyRoot ?? this.keyRoot,
      keyScale: keyScale ?? this.keyScale,
    );
  }
}

enum SnapResolution { eighth, sixteenth }

enum ScaleType { major, minor }

extension ScaleTypeExt on ScaleType {
  String get name => this == ScaleType.major ? 'Major' : 'Minor';
}

/// Note name helper
class NoteNames {
  static const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  static String fromRoot(int root) => names[root % 12];

  static String keyName(int root, ScaleType scale) =>
      '${fromRoot(root)} ${scale.name}';
}
