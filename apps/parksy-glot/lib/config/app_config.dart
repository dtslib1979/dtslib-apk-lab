import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static late SharedPreferences _prefs;

  static const String _keyApiKey = 'openai_api_key';
  static const String _keySourceLang = 'source_language';
  static const String _keyAutoDetect = 'auto_detect';
  static const String _keyShowOriginal = 'show_original';
  static const String _keySubtitleSize = 'subtitle_size';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // OpenAI API Key
  static String get apiKey => _prefs.getString(_keyApiKey) ?? '';
  static set apiKey(String value) => _prefs.setString(_keyApiKey, value);

  // Source Language (auto, en, ja, es, fr, de, zh, ko)
  static String get sourceLanguage => _prefs.getString(_keySourceLang) ?? 'auto';
  static set sourceLanguage(String value) => _prefs.setString(_keySourceLang, value);

  // Auto Detect Language
  static bool get autoDetect => _prefs.getBool(_keyAutoDetect) ?? true;
  static set autoDetect(bool value) => _prefs.setBool(_keyAutoDetect, value);

  // Show Original Text
  static bool get showOriginal => _prefs.getBool(_keyShowOriginal) ?? false;
  static set showOriginal(bool value) => _prefs.setBool(_keyShowOriginal, value);

  // Subtitle Size (0.8 ~ 1.5)
  static double get subtitleSize => _prefs.getDouble(_keySubtitleSize) ?? 1.0;
  static set subtitleSize(double value) => _prefs.setDouble(_keySubtitleSize, value);

  // Platform channel for native features
  static const platform = MethodChannel('com.dtslib.parksy_glot/audio');
}
