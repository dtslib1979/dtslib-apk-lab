import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyServerUrl = 'tts_server_url';
  static const _keyAppSecret = 'tts_app_secret';
  static const _keyLastPreset = 'tts_last_preset';
  static const _keyLastLanguage = 'tts_last_language';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String get serverUrl => _prefs?.getString(_keyServerUrl) ?? '';
  String get appSecret => _prefs?.getString(_keyAppSecret) ?? '';
  String get lastPreset => _prefs?.getString(_keyLastPreset) ?? 'neutral';
  String get lastLanguage => _prefs?.getString(_keyLastLanguage) ?? 'en';

  bool get isConfigured => serverUrl.isNotEmpty && appSecret.isNotEmpty;

  Future<void> saveServerSettings(String url, String secret) async {
    await _prefs?.setString(_keyServerUrl, url.trim());
    await _prefs?.setString(_keyAppSecret, secret.trim());
  }

  Future<void> savePreset(String preset) async {
    await _prefs?.setString(_keyLastPreset, preset);
  }

  Future<void> saveLanguage(String language) async {
    await _prefs?.setString(_keyLastLanguage, language);
  }
}
