import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import '../models/transcript.dart';

class StorageService {
  // --- API Key ---
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefApiKey);
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefApiKey, key);
  }

  // --- Auto Share Setting ---
  static Future<bool> getAutoShare() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefAutoShare) ?? false;
  }

  static Future<void> setAutoShare(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefAutoShare, value);
  }

  // --- Transcript History ---
  static Future<List<Transcript>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(AppConstants.prefHistory);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      return Transcript.listFromJsonString(jsonStr);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTranscript(Transcript transcript) async {
    final history = await getHistory();
    history.insert(0, transcript);
    // Keep last 100 transcripts
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.prefHistory, Transcript.listToJsonString(history));
  }

  static Future<void> deleteTranscript(String id) async {
    final history = await getHistory();
    history.removeWhere((t) => t.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.prefHistory, Transcript.listToJsonString(history));
  }

  // --- Markdown Export ---
  static Future<String?> exportMarkdown(Transcript transcript) async {
    try {
      final baseDir = Directory('/storage/emulated/0/${AppConstants.exportDir}');
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final date = transcript.createdAt.toIso8601String().substring(0, 10);
      final safeName = transcript.fileName
          .replaceAll(RegExp(r'[^\w가-힣\s.-]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${date}_$safeName.md';
      final file = File('${baseDir.path}/$fileName');

      await file.writeAsString(transcript.toMarkdown());
      return file.path;
    } catch (e) {
      return null;
    }
  }
}
