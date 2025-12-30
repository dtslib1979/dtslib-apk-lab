import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subtitle_provider.dart';
import '../models/language.dart';
import '../config/app_config.dart';
import '../services/overlay_service.dart';
import '../widgets/language_selector.dart';
import '../widgets/dual_subtitle.dart';
import '../widgets/source_accordion.dart';
import '../utils/constants.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await OverlayService.hasPermission();
    setState(() => _hasOverlayPermission = hasPermission);
  }

  Future<void> _requestOverlayPermission() async {
    await OverlayService.requestPermission();
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildBody(),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          // App title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.appName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                AppStrings.appTagline,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: Colors.white.withOpacity(0.7),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<SubtitleProvider>(
      builder: (context, provider, _) {
        if (!_hasOverlayPermission) {
          return _buildPermissionRequest();
        }

        if (AppConfig.apiKey.isEmpty) {
          return _buildApiKeyPrompt();
        }

        return _buildMainContent(provider);
      },
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.layers_outlined,
                size: 48,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '오버레이 권한 필요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '다른 앱 위에 자막을 표시하려면\n오버레이 권한이 필요합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestOverlayPermission,
              icon: const Icon(Icons.security),
              label: const Text('권한 허용'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.key,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'API 키 설정',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'OpenAI API 키를 설정하면\n음성 인식과 번역을 시작할 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('설정으로 이동'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(SubtitleProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Language selector
          Row(
            children: [
              Text(
                '소스 언어',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              LanguageSelector(
                selectedLanguage: provider.sourceLanguage,
                onChanged: provider.setSourceLanguage,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Current subtitle preview
          Expanded(
            child: provider.currentSubtitle.isNotEmpty
                ? _buildSubtitlePreview(provider)
                : _buildIdleState(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlePreview(SubtitleProvider provider) {
    return Column(
      children: [
        DualSubtitle(
          subtitle: provider.currentSubtitle,
        ),
        const SizedBox(height: 12),
        SourceAccordion(
          subtitle: provider.currentSubtitle,
          initiallyExpanded: provider.showOriginal,
        ),
        const SizedBox(height: 24),
        // History
        Expanded(
          child: _buildHistory(provider),
        ),
      ],
    );
  }

  Widget _buildHistory(SubtitleProvider provider) {
    if (provider.history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '히스토리',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: provider.clearHistory,
              child: Text(
                '지우기',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: provider.history.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final subtitle = provider.history[index];
              return DualSubtitle(
                subtitle: subtitle,
                compact: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIdleState(SubtitleProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            provider.isCapturing
                ? Icons.mic
                : Icons.subtitles_outlined,
            size: 64,
            color: provider.isCapturing
                ? AppColors.success
                : Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            provider.isCapturing
                ? '음성을 기다리는 중...'
                : '시작 버튼을 눌러\n실시간 자막을 시작하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          if (provider.hasError && provider.errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Consumer<SubtitleProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              // Original toggle
              GestureDetector(
                onTap: provider.toggleOriginal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: provider.showOriginal
                        ? AppColors.primary.withOpacity(0.2)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: provider.showOriginal
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        provider.showOriginal
                            ? Icons.subtitles
                            : Icons.subtitles_outlined,
                        color: provider.showOriginal
                            ? AppColors.primary
                            : Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '원문',
                        style: TextStyle(
                          color: provider.showOriginal
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Main action button
              _buildMainButton(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainButton(SubtitleProvider provider) {
    final isCapturing = provider.isCapturing;
    final isPreparing = provider.isPreparing;

    return GestureDetector(
      onTap: isPreparing
          ? null
          : () {
              if (isCapturing) {
                provider.stopCapture();
              } else {
                provider.startCapture();
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: isCapturing ? AppColors.error : AppColors.success,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isCapturing ? AppColors.error : AppColors.success)
                  .withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPreparing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                isCapturing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            const SizedBox(width: 8),
            Text(
              isPreparing
                  ? '준비 중...'
                  : isCapturing
                      ? '중지'
                      : '시작',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
