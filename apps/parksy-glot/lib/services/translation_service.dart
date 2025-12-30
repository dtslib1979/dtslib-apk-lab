import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/subtitle.dart';
import '../models/language.dart';
import '../utils/error_handler.dart';
import 'translation_cache.dart';

class TranslationService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const Duration _timeout = Duration(seconds: 30);

  // 싱글톤 캐시
  static final TranslationCache _cache = TranslationCache(maxSize: 500);

  // 통계
  int _apiCalls = 0;
  int _cachedResults = 0;

  /// 캐시 통계
  String get cacheStats =>
      'API: $_apiCalls, Cached: $_cachedResults, ${_cache.toString()}';

  /// Translate text to Korean and English using GPT-4o
  Future<TranslationResult> translate(
    String text, {
    Language sourceLanguage = Language.auto,
    bool includeNativeNote = false,
    bool useCache = true,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return TranslationResult(korean: '', english: '');
    }

    // 1. 캐시 확인
    if (useCache) {
      final cached = _cache.get(trimmed);
      if (cached != null) {
        _cachedResults++;
        return cached;
      }

      // 유사 텍스트 검색 (85% 이상 유사)
      final similar = _cache.findSimilar(trimmed, threshold: 0.85);
      if (similar != null) {
        _cachedResults++;
        return similar;
      }
    }

    // 2. API 호출 (재시도 포함)
    final result = await RetryHelper.retry(
      action: () => _callApi(trimmed, sourceLanguage, includeNativeNote),
      maxAttempts: 3,
      initialDelay: const Duration(seconds: 1),
    );

    // 3. 캐시에 저장
    if (useCache && result.korean.isNotEmpty) {
      _cache.put(trimmed, result);
    }

    _apiCalls++;
    return result;
  }

  Future<TranslationResult> _callApi(
    String text,
    Language sourceLanguage,
    bool includeNativeNote,
  ) async {
    final prompt = _buildPrompt(text, sourceLanguage, includeNativeNote);

    final response = await http
        .post(
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
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(
        'Translation failed',
        statusCode: response.statusCode,
        details: response.body,
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

  /// 캐시 초기화
  void clearCache() {
    _cache.clear();
    _apiCalls = 0;
    _cachedResults = 0;
  }
}
