import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/tts_item.dart';

class TTSService {
  final String serverUrl;
  final String appSecret;

  static const _timeout = Duration(seconds: 30);
  static const _downloadTimeout = Duration(minutes: 5);
  static const _maxRetries = 3;
  static const _downloadBasePath = '/storage/emulated/0/Download/TTS-Factory';

  TTSService({required this.serverUrl, required this.appSecret});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-app-secret': appSecret,
      };

  Future<T> _withRetry<T>(Future<T> Function() action) async {
    Exception? lastError;
    for (int i = 0; i < _maxRetries; i++) {
      try {
        return await action();
      } on SocketException catch (e) {
        lastError = e;
        if (i < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: (i + 1) * 2));
        }
      } on TimeoutException catch (e) {
        lastError = e;
        if (i < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: (i + 1) * 2));
        }
      }
    }
    throw TTSException('Network error after $_maxRetries retries: $lastError');
  }

  Future<String> createJob({
    required List<TTSItem> items,
    required String preset,
    required String language,
  }) async {
    return _withRetry(() async {
      final response = await http
          .post(
            Uri.parse('$serverUrl/v1/jobs'),
            headers: _headers,
            body: jsonEncode({
              'batch_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'preset': preset,
              'language': language,
              'items': items.map((e) => e.toJson()).toList(),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 202) {
        final data = jsonDecode(response.body);
        return data['job_id'] as String;
      } else if (response.statusCode == 401) {
        throw TTSException('Invalid app secret');
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw TTSException(data['error'] ?? 'Bad request');
      } else {
        throw TTSException('Server error: ${response.statusCode}');
      }
    });
  }

  Future<JobStatusResponse> getJobStatus(String jobId) async {
    final response = await http
        .get(
          Uri.parse('$serverUrl/v1/jobs/$jobId'),
          headers: {'x-app-secret': appSecret},
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return JobStatusResponse(
        status: data['status'] ?? 'unknown',
        progress: data['progress'] ?? 0,
        total: data['total'] ?? 0,
        error: data['error'],
      );
    } else if (response.statusCode == 404) {
      throw TTSException('Job not found');
    } else {
      throw TTSException('Failed to get status: ${response.statusCode}');
    }
  }

  Future<String> downloadResult(String jobId) async {
    await _ensureDownloadFolder();

    final response = await http
        .get(
          Uri.parse('$serverUrl/v1/jobs/$jobId/download'),
          headers: {'x-app-secret': appSecret},
        )
        .timeout(_downloadTimeout);

    if (response.statusCode == 200) {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'tts_$timestamp.zip';
      final file = File('$_downloadBasePath/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } else if (response.statusCode == 404) {
      throw TTSException('Download not ready');
    } else {
      throw TTSException('Download failed: ${response.statusCode}');
    }
  }

  Future<void> _ensureDownloadFolder() async {
    final dir = Directory(_downloadBasePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static String get downloadPath => _downloadBasePath;
}

class JobStatusResponse {
  final String status;
  final int progress;
  final int total;
  final String? error;

  JobStatusResponse({
    required this.status,
    required this.progress,
    required this.total,
    this.error,
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing' || status == 'queued';
}

class TTSException implements Exception {
  final String message;
  TTSException(this.message);

  @override
  String toString() => message;
}
