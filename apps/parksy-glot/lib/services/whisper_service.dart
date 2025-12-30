import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/subtitle.dart';

class WhisperService {
  static const String _baseUrl = 'https://api.openai.com/v1/audio';

  /// Transcribe audio bytes using Whisper API
  Future<TranscriptionResult> transcribe(
    Uint8List audioData, {
    String? language,
    String format = 'wav',
  }) async {
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
      filename: 'audio.$format',
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw WhisperException(
        'Transcription failed: ${response.statusCode}',
        response.body,
      );
    }

    final json = jsonDecode(response.body);
    return TranscriptionResult.fromWhisperResponse(json);
  }

  /// Transcribe audio from file path
  Future<TranscriptionResult> transcribeFile(
    String filePath, {
    String? language,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final ext = filePath.split('.').last;
    return transcribe(bytes, language: language, format: ext);
  }

  /// Stream transcription for real-time processing
  Stream<TranscriptionResult> transcribeStream(
    Stream<Uint8List> audioStream, {
    String? language,
    Duration chunkDuration = const Duration(seconds: 3),
  }) async* {
    final buffer = <int>[];

    await for (final chunk in audioStream) {
      buffer.addAll(chunk);

      // Process when buffer reaches ~3 seconds of audio
      // Assuming 16kHz mono 16-bit = 96000 bytes per 3 seconds
      if (buffer.length >= 96000) {
        final audioData = Uint8List.fromList(buffer);
        buffer.clear();

        try {
          final result = await transcribe(
            audioData,
            language: language,
            format: 'wav',
          );
          if (result.text.isNotEmpty) {
            yield result;
          }
        } catch (e) {
          // Log error but continue streaming
          print('Transcription chunk error: $e');
        }
      }
    }

    // Process remaining buffer
    if (buffer.isNotEmpty) {
      try {
        final result = await transcribe(
          Uint8List.fromList(buffer),
          language: language,
          format: 'wav',
        );
        if (result.text.isNotEmpty) {
          yield result;
        }
      } catch (e) {
        print('Final chunk error: $e');
      }
    }
  }
}

class WhisperException implements Exception {
  final String message;
  final String? details;

  WhisperException(this.message, [this.details]);

  @override
  String toString() => 'WhisperException: $message${details != null ? '\n$details' : ''}';
}
