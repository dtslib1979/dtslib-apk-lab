import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _keyDeepSeek = 'deepseek_api_key';
  static const String _keyGitHubRepo = 'github_repo';
  static const String _keyGitHubToken = 'github_token';

  static String? deepseekKey;
  static String? githubRepo;
  static String? githubToken;

  static bool get isDeepSeekConfigured =>
      deepseekKey != null && deepseekKey!.isNotEmpty;

  static bool get isGitHubConfigured =>
      githubToken != null && githubToken!.isNotEmpty &&
      githubRepo != null && githubRepo!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    deepseekKey = prefs.getString(_keyDeepSeek)?.trim();
    githubToken = prefs.getString(_keyGitHubToken)?.trim();
    githubRepo = (prefs.getString(_keyGitHubRepo) ?? 'dtslib1979/parksy-logs').trim();
  }

  static Future<void> save({
    String? deepseekKeyVal,
    String? githubRepoVal,
    String? githubTokenVal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (deepseekKeyVal != null) {
      final trimmed = deepseekKeyVal.trim();
      await prefs.setString(_keyDeepSeek, trimmed);
      deepseekKey = trimmed;
    }
    if (githubRepoVal != null) {
      final trimmed = githubRepoVal.trim();
      await prefs.setString(_keyGitHubRepo, trimmed);
      githubRepo = trimmed;
    }
    if (githubTokenVal != null) {
      final trimmed = githubTokenVal.trim();
      await prefs.setString(_keyGitHubToken, trimmed);
      githubToken = trimmed;
    }
  }
}
