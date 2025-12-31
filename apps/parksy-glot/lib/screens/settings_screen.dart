import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late double _subtitleSize;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: AppConfig.apiKey);
    _subtitleSize = AppConfig.subtitleSize;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveApiKey() {
    AppConfig.apiKey = _apiKeyController.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API 키가 저장되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            title: 'OpenAI API',
            children: [
              _buildApiKeyField(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '자막 설정',
            children: [
              _buildSubtitleSizeSlider(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '정보',
            children: [
              _buildInfoTile('버전', 'v1.0.0'),
              _buildInfoTile('개발', 'Parksy'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API Key',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'sk-...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                    ),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscureApiKey = !_obscureApiKey);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saveApiKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('저장'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'OpenAI API 키는 Whisper (음성인식)와 GPT-4o (번역)에 사용됩니다',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleSizeSlider() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '자막 크기',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${(_subtitleSize * 100).round()}%',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.2),
            ),
            child: Slider(
              value: _subtitleSize,
              min: 0.8,
              max: 1.5,
              divisions: 7,
              onChanged: (value) {
                setState(() => _subtitleSize = value);
                AppConfig.subtitleSize = value;
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '작게',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
              Text(
                '크게',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
