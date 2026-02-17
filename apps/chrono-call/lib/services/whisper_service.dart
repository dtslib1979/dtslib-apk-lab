import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/transcript.dart';

class WhisperService {
  final Dio _dio;

  WhisperService({String? apiKey})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5), // Long recordings
        )) {
    if (apiKey != null) {
      _dio.options.headers['Authorization'] = 'Bearer $apiKey';
    }
  }

  void updateApiKey(String apiKey) {
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
  }

  /// Transcribe audio file using OpenAI Whisper API.
  /// Returns verbose JSON with timestamps.
  Future<WhisperResult> transcribe({
    required String filePath,
    String language = 'ko',
    Function(double)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return WhisperResult.error('File not found: $filePath');
    }

    final fileSize = await file.length();
    final fileSizeMB = fileSize / (1024 * 1024);
    if (fileSizeMB > AppConstants.maxFileSizeMB) {
      return WhisperResult.error(
          'File too large: ${fileSizeMB.toStringAsFixed(1)}MB (max ${AppConstants.maxFileSizeMB}MB)');
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        'model': AppConstants.whisperModel,
        'language': language,
        'response_format': 'verbose_json',
        'timestamp_granularities[]': 'segment',
      });

      final response = await _dio.post(
        AppConstants.whisperEndpoint,
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode == 200) {
        return _parseResponse(response.data);
      } else {
        return WhisperResult.error(
            'API error ${response.statusCode}: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return WhisperResult.error('Connection timeout. Check your internet.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        return WhisperResult.error('Server timeout. File may be too long.');
      } else if (e.response?.statusCode == 401) {
        return WhisperResult.error('Invalid API key. Check settings.');
      } else if (e.response?.statusCode == 429) {
        return WhisperResult.error('Rate limited. Wait a moment and retry.');
      } else {
        return WhisperResult.error('Network error: ${e.message}');
      }
    } catch (e) {
      return WhisperResult.error('Unexpected error: $e');
    }
  }

  WhisperResult _parseResponse(dynamic data) {
    try {
      final Map<String, dynamic> json =
          data is String ? jsonDecode(data) : data;

      final text = json['text'] as String? ?? '';
      final language = json['language'] as String? ?? 'ko';
      final duration = (json['duration'] as num?)?.toDouble() ?? 0;

      final segments = <TranscriptSegment>[];
      if (json['segments'] != null) {
        for (final seg in json['segments'] as List) {
          segments.add(TranscriptSegment(
            start: (seg['start'] as num).toDouble(),
            end: (seg['end'] as num).toDouble(),
            text: (seg['text'] as String).trim(),
          ));
        }
      }

      return WhisperResult(
        success: true,
        text: text,
        segments: segments,
        language: language,
        durationSeconds: duration,
      );
    } catch (e) {
      return WhisperResult.error('Failed to parse response: $e');
    }
  }
}

class WhisperResult {
  final bool success;
  final String? text;
  final List<TranscriptSegment> segments;
  final String? language;
  final double durationSeconds;
  final String? errorMessage;

  WhisperResult({
    required this.success,
    this.text,
    this.segments = const [],
    this.language,
    this.durationSeconds = 0,
    this.errorMessage,
  });

  factory WhisperResult.error(String message) {
    return WhisperResult(success: false, errorMessage: message);
  }
}
