import 'dart:collection';
import '../models/subtitle.dart';

/// LRU 캐시 기반 번역 캐싱
class TranslationCache {
  final int maxSize;
  final LinkedHashMap<String, TranslationResult> _cache = LinkedHashMap();

  // 통계
  int _hits = 0;
  int _misses = 0;

  TranslationCache({this.maxSize = 500});

  /// 캐시 키 생성 (텍스트 정규화)
  String _createKey(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 캐시에서 조회
  TranslationResult? get(String text) {
    final key = _createKey(text);
    final result = _cache[key];

    if (result != null) {
      _hits++;
      // LRU: 최근 사용된 항목을 맨 뒤로 이동
      _cache.remove(key);
      _cache[key] = result;
      return result;
    }

    _misses++;
    return null;
  }

  /// 캐시에 저장
  void put(String text, TranslationResult result) {
    final key = _createKey(text);

    // 이미 있으면 제거 (순서 갱신을 위해)
    _cache.remove(key);

    // 크기 초과시 가장 오래된 항목 제거
    while (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = result;
  }

  /// 유사 텍스트 검색 (fuzzy matching)
  TranslationResult? findSimilar(String text, {double threshold = 0.85}) {
    final key = _createKey(text);

    for (final entry in _cache.entries) {
      final similarity = _calculateSimilarity(entry.key, key);
      if (similarity >= threshold) {
        _hits++;
        return entry.value;
      }
    }

    return null;
  }

  /// 레벤슈타인 거리 기반 유사도 계산
  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final maxLen = a.length > b.length ? a.length : b.length;
    final distance = _levenshteinDistance(a, b);

    return 1.0 - (distance / maxLen);
  }

  int _levenshteinDistance(String a, String b) {
    final m = a.length;
    final n = b.length;

    if (m == 0) return n;
    if (n == 0) return m;

    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) dp[i][0] = i;
    for (var j = 0; j <= n; j++) dp[0][j] = j;

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[m][n];
  }

  /// 캐시 초기화
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  /// 통계
  int get size => _cache.length;
  int get hits => _hits;
  int get misses => _misses;
  double get hitRate => _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0;

  @override
  String toString() {
    return 'TranslationCache(size: $size/$maxSize, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}
