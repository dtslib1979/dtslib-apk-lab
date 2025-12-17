import 'dart:math' as math;
import 'yin_detector.dart';

/// A note event with start time, duration, and MIDI note number
class NoteEvent {
  final double startTime; // seconds
  final double duration; // seconds
  final int midiNote; // 36-84

  NoteEvent({
    required this.startTime,
    required this.duration,
    required this.midiNote,
  });

  double get endTime => startTime + duration;

  @override
  String toString() =>
      'Note($midiNote, ${startTime.toStringAsFixed(3)}s, ${duration.toStringAsFixed(3)}s)';
}

/// Post-processing for pitch detection results
/// Applies 4 rules in order:
/// 1. Pitch clamp (MIDI 36-84, discard out-of-range)
/// 2. Median filter (5 frames)
/// 3. Min duration (120ms)
/// 4. Merge within 50 cents
class PitchPostProcessor {
  static const int midiMin = 36; // C2
  static const int midiMax = 84; // C6
  static const int medianWindowSize = 5;
  static const double minDurationMs = 120.0;
  static const double mergeCentsThreshold = 50.0;

  /// Process raw pitch frames into note events
  static List<NoteEvent> process(List<PitchFrame> frames) {
    if (frames.isEmpty) return [];

    // Step 1: Convert to MIDI and clamp (discard out-of-range, no interpolation)
    final midiFrames = _pitchClamp(frames);

    // Step 2: Median filter (5 frames)
    final filtered = _medianFilter(midiFrames);

    // Step 3 & 4: Convert to notes with min duration and merge
    final notes = _framesToNotes(filtered, frames);

    return notes;
  }

  /// Step 1: Pitch clamp - convert to MIDI, discard out-of-range
  static List<int?> _pitchClamp(List<PitchFrame> frames) {
    return frames.map((f) {
      if (f.frequencyHz == null) return null;
      final midi = YinDetector.frequencyToMidi(f.frequencyHz);
      if (midi == null || midi < midiMin || midi > midiMax) return null;
      return midi;
    }).toList();
  }

  /// Step 2: Median filter with window size 5
  static List<int?> _medianFilter(List<int?> midiFrames) {
    if (midiFrames.length < medianWindowSize) return midiFrames;

    final result = List<int?>.filled(midiFrames.length, null);
    final halfWindow = medianWindowSize ~/ 2;

    for (int i = 0; i < midiFrames.length; i++) {
      // Collect values in window
      final window = <int>[];
      for (int j = i - halfWindow; j <= i + halfWindow; j++) {
        if (j >= 0 && j < midiFrames.length && midiFrames[j] != null) {
          window.add(midiFrames[j]!);
        }
      }

      if (window.isEmpty) {
        result[i] = null;
      } else {
        // Median
        window.sort();
        result[i] = window[window.length ~/ 2];
      }
    }

    return result;
  }

  /// Steps 3 & 4: Convert frames to notes with min duration and merge
  static List<NoteEvent> _framesToNotes(
      List<int?> midiFrames, List<PitchFrame> originalFrames) {
    if (midiFrames.isEmpty) return [];

    final notes = <NoteEvent>[];
    final minDurationSec = minDurationMs / 1000.0;

    int? currentNote;
    double? noteStartTime;
    int frameCount = 0;

    for (int i = 0; i < midiFrames.length; i++) {
      final midi = midiFrames[i];
      final time = originalFrames[i].timeSeconds;

      if (midi == null) {
        // End current note if any
        if (currentNote != null && noteStartTime != null) {
          final duration = time - noteStartTime;
          if (duration >= minDurationSec) {
            notes.add(NoteEvent(
              startTime: noteStartTime,
              duration: duration,
              midiNote: currentNote,
            ));
          }
        }
        currentNote = null;
        noteStartTime = null;
        frameCount = 0;
      } else if (currentNote == null) {
        // Start new note
        currentNote = midi;
        noteStartTime = time;
        frameCount = 1;
      } else if (_shouldMerge(currentNote, midi)) {
        // Continue current note (within 50 cents)
        frameCount++;
      } else {
        // Different note - end current and start new
        final duration = time - noteStartTime!;
        if (duration >= minDurationSec) {
          notes.add(NoteEvent(
            startTime: noteStartTime,
            duration: duration,
            midiNote: currentNote,
          ));
        }
        currentNote = midi;
        noteStartTime = time;
        frameCount = 1;
      }
    }

    // Handle last note
    if (currentNote != null && noteStartTime != null) {
      final lastTime = originalFrames.last.timeSeconds +
          (YinDetector.hopSize / YinDetector.sampleRate);
      final duration = lastTime - noteStartTime;
      if (duration >= minDurationSec) {
        notes.add(NoteEvent(
          startTime: noteStartTime,
          duration: duration,
          midiNote: currentNote,
        ));
      }
    }

    return notes;
  }

  /// Check if two MIDI notes should be merged (within 50 cents)
  /// Since we're dealing with integer MIDI notes, 50 cents = 0.5 semitone
  /// So same MIDI note = merge, adjacent = don't merge (100 cents apart)
  static bool _shouldMerge(int midi1, int midi2) {
    // 50 cents = 0.5 semitone, so only merge if same note
    return midi1 == midi2;
  }

  /// Get statistics about the processed notes
  static Map<String, dynamic> getStats(List<NoteEvent> notes) {
    if (notes.isEmpty) {
      return {
        'noteCount': 0,
        'totalDuration': 0.0,
        'avgNoteDuration': 0.0,
        'midiRange': [0, 0],
      };
    }

    final durations = notes.map((n) => n.duration).toList();
    final midiNotes = notes.map((n) => n.midiNote).toList();

    return {
      'noteCount': notes.length,
      'totalDuration': notes.last.endTime - notes.first.startTime,
      'avgNoteDuration': durations.reduce((a, b) => a + b) / notes.length,
      'midiRange': [midiNotes.reduce(math.min), midiNotes.reduce(math.max)],
    };
  }
}
