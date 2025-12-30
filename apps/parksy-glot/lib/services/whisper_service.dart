import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/subtitle.dart';
import '../utils/error_handler.dart';

class WhisperService {
  static const String _baseUrl = 'https://api.openai.com/v1/audio';
  static const Duration _timeout = Duration(seconds: 60);

  // 버퍼 설정
  static const int _sampleRate = 16000;
  static const int _bytesPerSample = 2; // 16-bit
  static const int _channels = 1; // mono

  // 적응형 버퍼 크기 (2~5초)
  int _minBufferBytes = _sampleRate * _bytesPerSample * 2; // 2초
  int _maxBufferBytes = _sampleRate * _bytesPerSample * 5; // 5초
  int _currentBufferTarget = _sampleRate * _bytesPerSample * 3; // 3초 시작

  // 음성 활동 감지 (VAD) 임계값
  static const double _silenceThreshold = 500.0; // RMS 기준
  static const int _silenceFrames = 8000; // 0.5초 무음

  /// Transcribe audio bytes using Whisper API
  Future<TranscriptionResult> transcribe(
    Uint8List audioData, {
    String? language,
    String format = 'wav',
  }) async {
    // WAV 헤더 추가
    final wavData = _addWavHeader(audioData);

    return RetryHelper.retry(
      action: () => _callWhisperApi(wavData, language),
      maxAttempts: 3,
      initialDelay: const Duration(seconds: 1),
    );
  }

  Future<TranscriptionResult> _callWhisperApi(
    Uint8List audioData,
    String? language,
  ) async {
    final uri = Uri.parse('$_baseUrl/transcriptions');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${AppConfig.apiKey}'
      ..fields['model'] = 'whisper-1'
      ..fields['response_format'] = 'verbose_json';

    if (language != null && language != 'auto') {
      request.fields['language'] = language;
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      audioData,
      filename: 'audio.wav',
    ));

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(
        'Transcription failed',
        statusCode: response.statusCode,
        details: response.body,
      );
    }

    final json = jsonDecode(response.body);
    return TranscriptionResult.fromWhisperResponse(json);
  }

  /// Stream transcription with VAD and adaptive buffering
  Stream<TranscriptionResult> transcribeStream(
    Stream<Uint8List> audioStream, {
    String? language,
  }) async* {
    final buffer = <int>[];
    int silenceCount = 0;
    bool hasVoice = false;
    DateTime? lastTranscription;

    await for (final chunk in audioStream) {
      buffer.addAll(chunk);

      // VAD 체크
      final rms = _calculateRMS(chunk);
      final isSilence = rms < _silenceThreshold;

      if (isSilence) {
        silenceCount += chunk.length;
      } else {
        silenceCount = 0;
        hasVoice = true;
      }

      // 버퍼 처리 조건:
      // 1. 최대 버퍼 도달
      // 2. 음성 후 무음 감지 (문장 끝)
      // 3. 최소 버퍼 + 일정 시간 경과
      final shouldProcess = buffer.length >= _maxBufferBytes ||
          (hasVoice && silenceCount >= _silenceFrames && buffer.length >= _minBufferBytes) ||
          (buffer.length >= _currentBufferTarget && _timeSinceLastTranscription(lastTranscription) > 4);

      if (shouldProcess && buffer.length >= _minBufferBytes) {
        final audioData = Uint8List.fromList(buffer);
        buffer.clear();
        silenceCount = 0;
        hasVoice = false;

        try {
          final result = await transcribe(audioData, language: language);

          if (result.text.trim().isNotEmpty) {
            lastTranscription = DateTime.now();
            _adjustBufferSize(result);
            yield result;
          }
        } catch (e) {
          ErrorHandler.log(e);
          // 에러 시 버퍼 크기 증가 (안정성)
          _currentBufferTarget = min(_currentBufferTarget + 16000, _maxBufferBytes);
        }
      }
    }

    // 남은 버퍼 처리
    if (buffer.length >= _minBufferBytes ~/ 2) {
      try {
        final result = await transcribe(
          Uint8List.fromList(buffer),
          language: language,
        );
        if (result.text.trim().isNotEmpty) {
          yield result;
        }
      } catch (e) {
        ErrorHandler.log(e);
      }
    }
  }

  /// RMS (Root Mean Square) 계산 - 음량 레벨
  double _calculateRMS(Uint8List chunk) {
    if (chunk.length < 2) return 0.0;

    double sum = 0.0;
    final samples = chunk.length ~/ 2;

    for (var i = 0; i < chunk.length - 1; i += 2) {
      // 16-bit signed little-endian
      final sample = (chunk[i + 1] << 8) | chunk[i];
      final signed = sample > 32767 ? sample - 65536 : sample;
      sum += signed * signed;
    }

    return sqrt(sum / samples);
  }

  /// 마지막 변환 이후 시간
  int _timeSinceLastTranscription(DateTime? last) {
    if (last == null) return 999;
    return DateTime.now().difference(last).inSeconds;
  }

  /// 결과에 따라 버퍼 크기 조정
  void _adjustBufferSize(TranscriptionResult result) {
    final wordCount = result.text.split(' ').length;

    if (wordCount < 3) {
      // 짧은 문장 - 버퍼 증가
      _currentBufferTarget = min(_currentBufferTarget + 8000, _maxBufferBytes);
    } else if (wordCount > 15) {
      // 긴 문장 - 버퍼 감소
      _currentBufferTarget = max(_currentBufferTarget - 8000, _minBufferBytes);
    }
  }

  /// WAV 헤더 추가
  Uint8List _addWavHeader(Uint8List pcmData) {
    final dataSize = pcmData.length;
    final fileSize = dataSize + 36;

    final header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, _channels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * _channels * _bytesPerSample, Endian.little);
    header.setUint16(32, _channels * _bytesPerSample, Endian.little);
    header.setUint16(34, _bytesPerSample * 8, Endian.little);

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    // Combine header and data
    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcmData);

    return result;
  }

  /// Transcribe audio from file path
  Future<TranscriptionResult> transcribeFile(
    String filePath, {
    String? language,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return transcribe(bytes, language: language);
  }
}
