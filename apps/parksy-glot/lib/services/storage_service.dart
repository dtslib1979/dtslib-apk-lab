import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/subtitle.dart';

class StorageService {
  static const String _sessionsDir = 'sessions';

  /// Get app documents directory
  static Future<Directory> get _appDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  /// Get sessions directory
  static Future<Directory> get _sessionDir async {
    final appDir = await _appDir;
    final sessionsPath = Directory('${appDir.path}/$_sessionsDir');
    if (!await sessionsPath.exists()) {
      await sessionsPath.create(recursive: true);
    }
    return sessionsPath;
  }

  /// Create new session ID
  static String createSessionId() {
    final now = DateTime.now();
    return DateFormat('yyyyMMdd_HHmmss').format(now);
  }

  /// Save subtitles for a session
  static Future<String> saveSession({
    required String sessionId,
    required List<Subtitle> subtitles,
    String? title,
  }) async {
    final dir = await _sessionDir;
    final file = File('${dir.path}/$sessionId.json');

    final data = {
      'sessionId': sessionId,
      'title': title ?? 'Session $sessionId',
      'createdAt': DateTime.now().toIso8601String(),
      'subtitleCount': subtitles.length,
      'subtitles': subtitles.map((s) => s.toJson()).toList(),
    };

    await file.writeAsString(jsonEncode(data), flush: true);
    return file.path;
  }

  /// Load session
  static Future<SessionData?> loadSession(String sessionId) async {
    final dir = await _sessionDir;
    final file = File('${dir.path}/$sessionId.json');

    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final json = jsonDecode(content);

    return SessionData.fromJson(json);
  }

  /// List all sessions
  static Future<List<SessionInfo>> listSessions() async {
    final dir = await _sessionDir;
    final files = await dir.list().where((f) => f.path.endsWith('.json')).toList();

    final sessions = <SessionInfo>[];
    for (final file in files) {
      try {
        final content = await File(file.path).readAsString();
        final json = jsonDecode(content);
        sessions.add(SessionInfo.fromJson(json));
      } catch (e) {
        // Skip invalid files
      }
    }

    // Sort by date descending
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  /// Delete session
  static Future<void> deleteSession(String sessionId) async {
    final dir = await _sessionDir;
    final file = File('${dir.path}/$sessionId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Export as plain text
  static Future<String> exportAsText(List<Subtitle> subtitles) async {
    final buffer = StringBuffer();

    for (final sub in subtitles) {
      buffer.writeln('═' * 50);
      if (sub.original.isNotEmpty) {
        buffer.writeln('[원문] ${sub.original}');
      }
      buffer.writeln('[한국어] ${sub.korean}');
      buffer.writeln('[English] ${sub.english}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Export as SRT format
  static Future<String> exportAsSrt(
    List<Subtitle> subtitles, {
    bool koreanOnly = false,
    bool englishOnly = false,
  }) async {
    final buffer = StringBuffer();
    var index = 1;
    var currentTime = Duration.zero;
    const subtitleDuration = Duration(seconds: 4);

    for (final sub in subtitles) {
      final start = _formatSrtTime(currentTime);
      final end = _formatSrtTime(currentTime + subtitleDuration);

      buffer.writeln(index);
      buffer.writeln('$start --> $end');

      if (koreanOnly) {
        buffer.writeln(sub.korean);
      } else if (englishOnly) {
        buffer.writeln(sub.english);
      } else {
        buffer.writeln(sub.korean);
        buffer.writeln(sub.english);
      }

      buffer.writeln();

      currentTime += subtitleDuration;
      index++;
    }

    return buffer.toString();
  }

  /// Export as JSON
  static Future<String> exportAsJson(List<Subtitle> subtitles) async {
    final data = subtitles.map((s) => s.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Save export to file
  static Future<String> saveExport({
    required String content,
    required String filename,
    required ExportFormat format,
  }) async {
    final dir = await getExternalStorageDirectory() ?? await _appDir;
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final ext = format.extension;
    final file = File('${exportDir.path}/$filename.$ext');
    await file.writeAsString(content, flush: true);

    return file.path;
  }

  static String _formatSrtTime(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$millis';
  }
}

enum ExportFormat {
  txt('txt'),
  srt('srt'),
  json('json');

  final String extension;
  const ExportFormat(this.extension);
}

class SessionInfo {
  final String sessionId;
  final String title;
  final DateTime createdAt;
  final int subtitleCount;

  SessionInfo({
    required this.sessionId,
    required this.title,
    required this.createdAt,
    required this.subtitleCount,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      sessionId: json['sessionId'],
      title: json['title'] ?? 'Untitled',
      createdAt: DateTime.parse(json['createdAt']),
      subtitleCount: json['subtitleCount'] ?? 0,
    );
  }
}

class SessionData {
  final SessionInfo info;
  final List<Subtitle> subtitles;

  SessionData({
    required this.info,
    required this.subtitles,
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    final subtitlesJson = json['subtitles'] as List<dynamic>;
    return SessionData(
      info: SessionInfo.fromJson(json),
      subtitles: subtitlesJson.map((s) => Subtitle.fromJson(s)).toList(),
    );
  }
}
