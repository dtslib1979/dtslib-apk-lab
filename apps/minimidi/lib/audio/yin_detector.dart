import 'dart:typed_data';
import 'dart:math' as math;

/// Pitch detection result for a single frame
class PitchFrame {
  final double timeSeconds;
  final double? frequencyHz; // null if unvoiced/uncertain
  final double confidence; // 0.0 to 1.0 (lower is better for YIN)

  PitchFrame({
    required this.timeSeconds,
    this.frequencyHz,
    required this.confidence,
  });

  bool get isVoiced => frequencyHz != null;
}

/// YIN pitch detection algorithm
/// Reference: de Cheveigné, A., & Kawahara, H. (2002).
/// "YIN, a fundamental frequency estimator for speech and music."
class YinDetector {
  // Fixed parameters as specified
  static const int sampleRate = 44100;
  static const int frameSize = 2048;
  static const int hopSize = 512;
  static const double confidenceThreshold = 0.1;

  // Frequency range for MIDI 36-84 (C2-C6)
  static const double minFreq = 65.41; // C2
  static const double maxFreq = 1046.50; // C6

  /// Detect pitch for entire audio buffer
  /// Returns list of PitchFrame for each analysis frame
  static List<PitchFrame> detectPitch(Int16List samples) {
    final results = <PitchFrame>[];
    final numFrames = (samples.length - frameSize) ~/ hopSize + 1;

    for (int i = 0; i < numFrames; i++) {
      final startSample = i * hopSize;
      final timeSeconds = startSample / sampleRate;

      // Extract frame
      final frame = Float64List(frameSize);
      for (int j = 0; j < frameSize; j++) {
        if (startSample + j < samples.length) {
          frame[j] = samples[startSample + j] / 32768.0; // normalize to -1..1
        }
      }

      // Run YIN on this frame
      final result = _yinFrame(frame);
      results.add(PitchFrame(
        timeSeconds: timeSeconds,
        frequencyHz: result.$1,
        confidence: result.$2,
      ));
    }

    return results;
  }

  /// YIN algorithm for a single frame
  /// Returns (frequency, confidence) where confidence is YIN's d' value (lower = better)
  static (double?, double) _yinFrame(Float64List frame) {
    final halfSize = frameSize ~/ 2;

    // Step 1 & 2: Difference function and cumulative mean normalized difference
    final d = Float64List(halfSize);
    d[0] = 1.0;

    double runningSum = 0.0;

    for (int tau = 1; tau < halfSize; tau++) {
      double sum = 0.0;
      for (int j = 0; j < halfSize; j++) {
        final delta = frame[j] - frame[j + tau];
        sum += delta * delta;
      }
      d[tau] = sum;

      runningSum += d[tau];
      if (runningSum != 0) {
        d[tau] = d[tau] * tau / runningSum;
      } else {
        d[tau] = 1.0;
      }
    }

    // Step 3: Absolute threshold
    // Find first tau where d[tau] < threshold
    int? tauEstimate;
    for (int tau = _minTau(); tau < _maxTau() && tau < halfSize; tau++) {
      if (d[tau] < confidenceThreshold) {
        // Step 4: Parabolic interpolation to refine
        while (tau + 1 < halfSize && d[tau + 1] < d[tau]) {
          tau++;
        }
        tauEstimate = tau;
        break;
      }
    }

    // If no estimate found using threshold, find global minimum in valid range
    if (tauEstimate == null) {
      double minVal = double.infinity;
      for (int tau = _minTau(); tau < _maxTau() && tau < halfSize; tau++) {
        if (d[tau] < minVal) {
          minVal = d[tau];
          tauEstimate = tau;
        }
      }
    }

    if (tauEstimate == null) {
      return (null, 1.0);
    }

    final confidence = d[tauEstimate];

    // Only accept if confidence is good enough
    if (confidence > confidenceThreshold) {
      return (null, confidence);
    }

    // Step 5: Parabolic interpolation for better precision
    double refinedTau = tauEstimate.toDouble();
    if (tauEstimate > 0 && tauEstimate < halfSize - 1) {
      final s0 = d[tauEstimate - 1];
      final s1 = d[tauEstimate];
      final s2 = d[tauEstimate + 1];
      final adjustment = (s2 - s0) / (2 * (2 * s1 - s2 - s0));
      if (adjustment.isFinite) {
        refinedTau += adjustment;
      }
    }

    final frequency = sampleRate / refinedTau;

    // Check if frequency is in valid range
    if (frequency < minFreq || frequency > maxFreq) {
      return (null, confidence);
    }

    return (frequency, confidence);
  }

  /// Minimum tau for max frequency (C6)
  static int _minTau() => (sampleRate / maxFreq).floor();

  /// Maximum tau for min frequency (C2)
  static int _maxTau() => (sampleRate / minFreq).ceil();

  /// Convert frequency to MIDI note number
  static int? frequencyToMidi(double? freq) {
    if (freq == null || freq <= 0) return null;
    final midi = 69 + 12 * (math.log(freq / 440.0) / math.ln2);
    final rounded = midi.round();
    // Clamp to MIDI 36-84 range
    if (rounded < 36 || rounded > 84) return null;
    return rounded;
  }

  /// Convert MIDI note number to frequency
  static double midiToFrequency(int midi) {
    return 440.0 * math.pow(2, (midi - 69) / 12.0);
  }

  /// Get cents difference between two frequencies
  static double centsDifference(double f1, double f2) {
    if (f1 <= 0 || f2 <= 0) return double.infinity;
    return 1200 * (math.log(f2 / f1) / math.ln2).abs();
  }
}
