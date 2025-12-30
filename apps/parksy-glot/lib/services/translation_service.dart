import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/subtitle.dart';
import '../models/language.dart';

class TranslationService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// Translate text to Korean and English using GPT-4o
  Future<TranslationResult> translate(
    String text, {
    Language sourceLanguage = Language.auto,
    bool includeNativeNote = false,
  }) async {
    if (text.trim().isEmpty) {
      return TranslationResult(korean: '', english: '');
    }

    final prompt = _buildPrompt(text, sourceLanguage, includeNativeNote);

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer ${AppConfig.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': '''You are an expert polyglot translator specializing in natural, native-sounding translations.
Your task is to translate spoken language into Korean and English.
- Preserve the original tone, nuance, and colloquial expressions
- Use natural conversational language, not formal/written style
- For idioms and slang, translate the meaning, not literally
- Keep translations concise for subtitle display

IMPORTANT: Respond ONLY in valid JSON format, no markdown.''',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.3,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode != 200) {
      throw TranslationException(
        'Translation failed: ${response.statusCode}',
        response.body,
      );
    }

    final json = jsonDecode(response.body);
    final content = json['choices'][0]['message']['content'] as String;

    return _parseResponse(content);
  }

  String _buildPrompt(String text, Language source, bool includeNote) {
    final langHint = source != Language.auto
        ? 'Source language: ${source.displayName}\n'
        : '';

    final noteRequest = includeNote
        ? ', "note": "brief explanation of any idioms/slang/cultural nuance"'
        : '';

    return '''${langHint}Translate the following to Korean and English:

"$text"

Respond in JSON format:
{"korean": "...", "english": "..."$noteRequest}''';
  }

  TranslationResult _parseResponse(String content) {
    try {
      // Clean up potential markdown code blocks
      var cleaned = content.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
      }

      final json = jsonDecode(cleaned);
      return TranslationResult(
        korean: json['korean'] ?? '',
        english: json['english'] ?? '',
        nativeNote: json['note'],
      );
    } catch (e) {
      // Fallback: try to extract translations from malformed response
      return TranslationResult(
        korean: _extractField(content, 'korean'),
        english: _extractField(content, 'english'),
      );
    }
  }

  String _extractField(String content, String field) {
    final pattern = RegExp('"$field"\\s*:\\s*"([^"]*)"');
    final match = pattern.firstMatch(content);
    return match?.group(1) ?? '';
  }

  /// Batch translate multiple texts
  Future<List<TranslationResult>> translateBatch(
    List<String> texts, {
    Language sourceLanguage = Language.auto,
  }) async {
    final results = <TranslationResult>[];

    for (final text in texts) {
      final result = await translate(text, sourceLanguage: sourceLanguage);
      results.add(result);
    }

    return results;
  }
}

class TranslationException implements Exception {
  final String message;
  final String? details;

  TranslationException(this.message, [this.details]);

  @override
  String toString() => 'TranslationException: $message';
}
