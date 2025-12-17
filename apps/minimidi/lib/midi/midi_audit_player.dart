import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../audio/pitch_post.dart';

/// Simple MIDI Audit Player
/// Purpose: Listen and verify MIDI output (NOT an editor)
/// Uses simple sine wave synthesis for portability
class MidiAuditPlayer {
  static const int sampleRate = 44100;
  static const int bpm = 120;
  static const double beatsPerSecond = bpm / 60.0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  List<NoteEvent>? _notes;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _loopEnabled = false;
  double _currentTime = 0;
  double _totalDuration = 0;

  Timer? _playbackTimer;
  final _positionController = StreamController<double>.broadcast();
  final _stateController = StreamController<PlayerState>.broadcast();

  Stream<double> get positionStream => _positionController.stream;
  Stream<PlayerState> get stateStream => _stateController.stream;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get loopEnabled => _loopEnabled;
  double get currentTime => _currentTime;
  double get totalDuration => _totalDuration;

  /// Load notes for playback
  void loadNotes(List<NoteEvent> notes) {
    stop();
    _notes = notes;
    _currentTime = 0;
    if (notes.isNotEmpty) {
      _totalDuration = notes.last.endTime;
    } else {
      _totalDuration = 0;
    }
    _stateController.add(PlayerState.stopped);
  }

  /// Set loop mode
  void setLoop(bool enabled) {
    _loopEnabled = enabled;
  }

  /// Play loaded notes
  Future<void> play() async {
    if (_notes == null || _notes!.isEmpty) return;

    if (_isPaused) {
      _isPaused = false;
      _isPlaying = true;
      _stateController.add(PlayerState.playing);
      _startPlaybackTimer();
      return;
    }

    stop();
    _isPlaying = true;
    _stateController.add(PlayerState.playing);

    // Render audio and play
    final audioBytes = _renderToWav(_notes!, _totalDuration);
    await _playAudioBytes(audioBytes);
  }

  /// Pause playback
  void pause() {
    if (!_isPlaying) return;
    _isPaused = true;
    _isPlaying = false;
    _playbackTimer?.cancel();
    _audioPlayer.pause();
    _stateController.add(PlayerState.paused);
  }

  /// Stop playback
  void stop() {
    _isPlaying = false;
    _isPaused = false;
    _currentTime = 0;
    _playbackTimer?.cancel();
    _audioPlayer.stop();
    _positionController.add(0);
    _stateController.add(PlayerState.stopped);
  }

  /// Seek to position (seconds)
  Future<void> seek(double seconds) async {
    _currentTime = seconds.clamp(0, _totalDuration);
    _positionController.add(_currentTime);
    if (_isPlaying) {
      await _audioPlayer.seek(Duration(milliseconds: (seconds * 1000).toInt()));
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      _currentTime += 0.05;
      _positionController.add(_currentTime);

      if (_currentTime >= _totalDuration) {
        if (_loopEnabled) {
          _currentTime = 0;
          _positionController.add(0);
          _audioPlayer.seek(Duration.zero);
        } else {
          stop();
        }
      }
    });
  }

  Future<void> _playAudioBytes(Uint8List wavBytes) async {
    try {
      // Create a custom audio source from bytes
      final source = _WavAudioSource(wavBytes);
      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
      _startPlaybackTimer();

      // Listen for completion
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (_loopEnabled && _isPlaying) {
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.play();
            _currentTime = 0;
          } else {
            stop();
          }
        }
      });
    } catch (e) {
      stop();
    }
  }

  /// Render notes to WAV bytes using simple sine wave synthesis
  Uint8List _renderToWav(List<NoteEvent> notes, double duration) {
    final numSamples = (duration * sampleRate).toInt() + sampleRate; // +1s buffer
    final samples = Float64List(numSamples);

    // Simple piano-like envelope
    for (final note in notes) {
      final freq = _midiToFreq(note.midiNote);
      final startSample = (note.startTime * sampleRate).toInt();
      final endSample = (note.endTime * sampleRate).toInt();
      final noteSamples = endSample - startSample;

      for (int i = 0; i < noteSamples && startSample + i < numSamples; i++) {
        final t = i / sampleRate;
        final envelope = _envelope(i, noteSamples);

        // Simple additive synthesis (fundamental + harmonics)
        double sample = 0;
        sample += math.sin(2 * math.pi * freq * t) * 0.6; // fundamental
        sample += math.sin(2 * math.pi * freq * 2 * t) * 0.2; // 2nd harmonic
        sample += math.sin(2 * math.pi * freq * 3 * t) * 0.1; // 3rd harmonic
        sample += math.sin(2 * math.pi * freq * 4 * t) * 0.05; // 4th harmonic

        samples[startSample + i] += sample * envelope * 0.3; // velocity
      }
    }

    // Normalize and convert to 16-bit PCM
    double maxAmp = 0;
    for (final s in samples) {
      if (s.abs() > maxAmp) maxAmp = s.abs();
    }
    if (maxAmp == 0) maxAmp = 1;

    final pcm = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      pcm[i] = ((samples[i] / maxAmp) * 32767 * 0.8).toInt().clamp(-32768, 32767);
    }

    return _createWav(pcm);
  }

  /// ADSR-like envelope
  double _envelope(int sample, int totalSamples) {
    final attackSamples = (0.01 * sampleRate).toInt(); // 10ms attack
    final decaySamples = (0.1 * sampleRate).toInt(); // 100ms decay
    final releaseSamples = (0.05 * sampleRate).toInt(); // 50ms release

    if (sample < attackSamples) {
      return sample / attackSamples;
    } else if (sample < attackSamples + decaySamples) {
      return 1.0 - 0.3 * ((sample - attackSamples) / decaySamples);
    } else if (sample > totalSamples - releaseSamples) {
      return 0.7 * ((totalSamples - sample) / releaseSamples);
    }
    return 0.7; // sustain level
  }

  double _midiToFreq(int midi) {
    return 440.0 * math.pow(2, (midi - 69) / 12.0);
  }

  /// Create WAV file bytes from PCM samples
  Uint8List _createWav(Int16List samples) {
    final dataSize = samples.length * 2;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    int offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // space
    buffer.setUint32(offset, 16, Endian.little); // chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, 1, Endian.little); // mono
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, sampleRate * 2, Endian.little); // byte rate
    offset += 4;
    buffer.setUint16(offset, 2, Endian.little); // block align
    offset += 2;
    buffer.setUint16(offset, 16, Endian.little); // bits per sample
    offset += 2;

    // data chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // PCM data
    for (final sample in samples) {
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  void dispose() {
    _playbackTimer?.cancel();
    _positionController.close();
    _stateController.close();
    _audioPlayer.dispose();
  }
}

enum PlayerState { stopped, playing, paused }

/// Custom audio source for just_audio from raw bytes
class _WavAudioSource extends StreamAudioSource {
  final Uint8List _bytes;

  _WavAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
