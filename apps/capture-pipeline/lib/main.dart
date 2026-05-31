import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ParksyCaptureApp());
}

// ============================================================
// APP ROOT
// ============================================================

class ParksyCaptureApp extends StatelessWidget {
  const ParksyCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Capture',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      home: const AppRouter(),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      primaryColor: const Color(0xFF58A6FF),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF58A6FF),
        secondary: Color(0xFF7EE787),
        surface: Color(0xFF161B22),
        error: Color(0xFFF85149),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF161B22),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1117),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF21262D),
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF161B22),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================
// API CONFIG - SharedPreferences 기반
// ============================================================

class ApiConfig {
  static const String _keyGitHubRepo = 'github_repo';
  static const String _keyGitHubToken = 'github_token';
  static const String _keyOnDevice = 'on_device_mode';

  static String? githubRepo;
  static String? githubToken;
  static bool onDeviceMode = true;  // 기본값: 온디바이스

  static bool get isAiConfigured => true;  // v11: 항상 사용 가능 (온디바이스)
  static bool get isGitHubConfigured =>
      githubToken != null && githubToken!.isNotEmpty &&
      githubRepo != null && githubRepo!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    githubToken = prefs.getString(_keyGitHubToken)?.trim();
    githubRepo = (prefs.getString(_keyGitHubRepo) ?? 'dtslib1979/parksy-logs').trim();
    onDeviceMode = prefs.getBool(_keyOnDevice) ?? true;
  }

  static Future<void> save({
    String? githubRepoVal,
    String? githubTokenVal,
    bool? onDeviceModeVal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
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
    if (onDeviceModeVal != null) {
      await prefs.setBool(_keyOnDevice, onDeviceModeVal);
      onDeviceMode = onDeviceModeVal;
    }
  }
}

// ============================================================
// ROUTER - 실행 모드 분기
// ============================================================

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  static const platform = MethodChannel('com.parksy.capture/share');
  bool _isLoading = true;
  bool _isShareIntent = false;
  bool _isFirstLaunch = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ApiConfig.load();
    await _checkLaunchMode();
  }

  Future<void> _checkLaunchMode() async {
    try {
      final isShare = await platform.invokeMethod<bool>('isShareIntent');
      final stats = await platform.invokeMethod<Map>('getStats');
      setState(() {
        _isShareIntent = isShare ?? false;
        _isFirstLaunch = (stats?['totalLogs'] ?? 0) == 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isShareIntent = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.catching_pokemon, size: 48, color: Color(0xFF58A6FF)),
              SizedBox(height: 16),
              Text('Parksy Capture', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    if (_isShareIntent) {
      return const ShareHandler();
    } else if (_isFirstLaunch) {
      return const OnboardingScreen();
    } else {
      return const HomeScreen();
    }
  }
}

// ============================================================
// ONBOARDING - 첫 실행 안내
// ============================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.block,
      title: 'Clipboard Fails on Mobile',
      description: 'Long LLM conversations get truncated when you copy them.\nClipboard has memory limits.',
      color: Color(0xFFF85149),
    ),
    _OnboardingPage(
      icon: Icons.share,
      title: 'Share Intent Bypasses Limits',
      description: 'Android Share Intent has no size limit.\nCapture entire conversations without loss.',
      color: Color(0xFF58A6FF),
    ),
    _OnboardingPage(
      icon: Icons.cloud_done,
      title: 'Auto Backup to GitHub',
      description: 'Logs sync to your private GitHub repo.\nAccess from any device, anytime.',
      color: Color(0xFF7EE787),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: page.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, size: 64, color: page.color),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          page.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF58A6FF)
                        : Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

// ============================================================
// SHARE HANDLER - 공유 받기
// ============================================================

class ShareHandler extends StatefulWidget {
  const ShareHandler({super.key});

  @override
  State<ShareHandler> createState() => _ShareHandlerState();
}

class _ShareHandlerState extends State<ShareHandler> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.parksy.capture/share');

  String _status = 'Receiving...';
  IconData _icon = Icons.downloading;
  Color _iconColor = const Color(0xFF58A6FF);
  bool _isDone = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _handleShare());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    try {
      final text = await platform.invokeMethod<String>('getSharedText');
      if (text == null || text.isEmpty) {
        _updateStatus('No text received', Icons.error_outline, const Color(0xFFF85149));
        _finish();
        return;
      }

      setState(() {
        _status = 'Saving locally...';
        _icon = Icons.save;
      });

      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fname = 'ParksyLog_$ts.md';
      final content = _toMarkdown(text);

      final localOk = await _saveLocal(fname, content);
      if (!localOk) {
        _updateStatus('Save failed', Icons.error, const Color(0xFFF85149));
        _finish();
        return;
      }

      if (!ApiConfig.isGitHubConfigured) {
        _updateStatus('Saved locally', Icons.check_circle, const Color(0xFF7EE787));
        _finish();
        return;
      }

      setState(() {
        _status = 'Syncing to GitHub...';
        _icon = Icons.cloud_upload;
      });

      final syncResult = await _syncToGitHub(fname, content);
      if (syncResult == null) {
        _updateStatus('Saved & Synced', Icons.cloud_done, const Color(0xFF7EE787));
        _finish();
      } else {
        // 동기화 실패 - 에러 원인 표시
        _updateStatus('⚠️ GitHub 실패: $syncResult', Icons.cloud_off, const Color(0xFFF85149));
        _finish(hasError: true);
      }
    } catch (e) {
      _updateStatus('Error: $e', Icons.error, const Color(0xFFF85149));
      _finish(hasError: true);
    }
  }

  void _updateStatus(String status, IconData icon, Color color) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _icon = icon;
      _iconColor = color;
      _isDone = true;
    });
    _animController.stop();
  }

  Future<bool> _saveLocal(String filename, String content) async {
    try {
      final result = await platform.invokeMethod<bool>(
        'saveToDownloads',
        {'filename': filename, 'content': content},
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// GitHub 동기화. 성공 시 null, 실패 시 에러 메시지 반환
  Future<String?> _syncToGitHub(String filename, String content) async {
    try {
      if (ApiConfig.githubToken == null || ApiConfig.githubToken!.isEmpty) {
        return 'Token 없음';
      }

      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final path = 'logs/$year/$month/$filename';

      final url = 'https://api.github.com/repos/${ApiConfig.githubRepo}/contents/$path';

      final res = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.githubToken}',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': 'Add $filename',
          'content': base64Encode(utf8.encode(content)),
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 201 || res.statusCode == 200) {
        return null; // 성공
      } else if (res.statusCode == 401) {
        return 'Token 만료/무효';
      } else if (res.statusCode == 403) {
        return 'Token 권한 부족';
      } else if (res.statusCode == 404) {
        return 'Repo 없음';
      } else {
        return 'HTTP ${res.statusCode}';
      }
    } on TimeoutException {
      return '타임아웃';
    } catch (e) {
      debugPrint('GitHub sync failed: $e');
      return '네트워크 오류';
    }
  }

  String _toMarkdown(String text) {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return '---\ndate: $ts\nsource: android-share\n---\n\n$text\n';
  }

  void _finish({bool hasError = false}) {
    // 에러 있으면 더 오래 표시 (3초)
    final delay = hasError ? 3 : 2;
    Future.delayed(Duration(seconds: delay), () {
      if (mounted) SystemNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isDone
                ? Icon(_icon, size: 64, color: _iconColor)
                : RotationTransition(
                    turns: _animController,
                    child: Icon(_icon, size: 64, color: _iconColor),
                  ),
            const SizedBox(height: 24),
            Text(
              _status,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SETTINGS SCREEN - 온디바이스 모드 설정
// ============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _onDeviceMode;
  final _githubRepoController = TextEditingController();
  final _githubTokenController = TextEditingController();
  bool _obscureGitHub = true;
  bool _isSaving = false;
  bool _isTesting = false;
  List<Map<String, dynamic>> _testResults = [];

  @override
  void initState() {
    super.initState();
    _onDeviceMode = ApiConfig.onDeviceMode;
    _githubRepoController.text = ApiConfig.githubRepo ?? '';
    _githubTokenController.text = ApiConfig.githubToken ?? '';
  }

  @override
  void dispose() {
    _githubRepoController.dispose();
    _githubTokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ApiConfig.save(
      githubRepoVal: _githubRepoController.text.trim(),
      githubTokenVal: _githubTokenController.text.trim(),
      onDeviceModeVal: _onDeviceMode,
    );
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장됨')),
      );
      Navigator.pop(context, true);
    }
  }

  /// GitHub 연결 테스트 (4단계)
  Future<void> _testGitHubConnection() async {
    final token = _githubTokenController.text.trim();
    final repo = _githubRepoController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Token을 입력하세요')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResults = [];
    });

    final results = <Map<String, dynamic>>[];

    // 1. Token 유효 체크
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/user'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        results.add({
          'step': '1. Token 체크',
          'ok': true,
          'msg': '유효함 (${data['login']})',
        });
      } else {
        results.add({
          'step': '1. Token 체크',
          'ok': false,
          'msg': 'HTTP ${res.statusCode}',
        });
      }
    } catch (e) {
      results.add({'step': '1. Token 체크', 'ok': false, 'msg': '$e'});
    }

    // 2. 권한 체크
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/user'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      final scopes = res.headers['x-oauth-scopes'] ?? '';
      final hasRepo = scopes.contains('repo') || scopes.contains('public_repo');
      results.add({
        'step': '2. 권한 체크',
        'ok': hasRepo || scopes.isEmpty,
        'msg': scopes.isEmpty ? 'Fine-grained token' : scopes,
      });
    } catch (e) {
      results.add({'step': '2. 권한 체크', 'ok': false, 'msg': '$e'});
    }

    // 3. 저장소 접근 체크
    if (repo.isNotEmpty) {
      try {
        final res = await http.get(
          Uri.parse('https://api.github.com/repos/$repo'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          results.add({
            'step': '3. 저장소 체크',
            'ok': true,
            'msg': repo,
          });
        } else if (res.statusCode == 404) {
          results.add({
            'step': '3. 저장소 체크',
            'ok': false,
            'msg': '저장소 없음 또는 접근 권한 없음',
          });
        } else {
          results.add({
            'step': '3. 저장소 체크',
            'ok': false,
            'msg': 'HTTP ${res.statusCode}',
          });
        }
      } catch (e) {
        results.add({'step': '3. 저장소 체크', 'ok': false, 'msg': '$e'});
      }
    }

    // 4. 테스트 업로드
    if (repo.isNotEmpty && results.where((r) => r['ok'] == true).length >= 2) {
      try {
        final testPath = 'logs/_test_connection.md';
        final testContent = '# Connection Test\nTime: ${DateTime.now()}\n';

        final res = await http.put(
          Uri.parse('https://api.github.com/repos/$repo/contents/$testPath'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'message': 'Connection test',
            'content': base64Encode(utf8.encode(testContent)),
          }),
        ).timeout(const Duration(seconds: 15));

        if (res.statusCode == 201 || res.statusCode == 200) {
          results.add({
            'step': '4. 테스트 업로드',
            'ok': true,
            'msg': '성공! 파일 생성됨',
          });
        } else if (res.statusCode == 422) {
          results.add({
            'step': '4. 테스트 업로드',
            'ok': true,
            'msg': '성공 (파일 이미 존재)',
          });
        } else {
          results.add({
            'step': '4. 테스트 업로드',
            'ok': false,
            'msg': 'HTTP ${res.statusCode}',
          });
        }
      } catch (e) {
        results.add({'step': '4. 테스트 업로드', 'ok': false, 'msg': '$e'});
      }
    }

    setState(() {
      _isTesting = false;
      _testResults = results;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _save,
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 온디바이스 RAG 모드
          _buildSectionHeader('온디바이스 RAG', Icons.psychology),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _onDeviceMode ? Icons.check_circle : Icons.cancel,
                        size: 20,
                        color: _onDeviceMode ? const Color(0xFF7EE787) : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '온디바이스 모드',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              _onDeviceMode
                                  ? '인터넷 불필요 · 0원 · NPU 가속'
                                  : 'GitHub 동기화만 사용',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _onDeviceMode,
                        onChanged: (val) => setState(() => _onDeviceMode = val),
                        activeColor: const Color(0xFF58A6FF),
                      ),
                    ],
                  ),
                  if (_onDeviceMode) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF30363D)),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.memory, '엔진', '온디바이스 LLM + 임베딩'),
                    const SizedBox(height: 4),
                    _buildInfoRow(Icons.wifi_off, '네트워크', '오프라인 작동'),
                    const SizedBox(height: 4),
                    _buildInfoRow(Icons.monetization_on, '비용', '과금 0원/월'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // GitHub Sync Section
          _buildSectionHeader('GitHub Sync', Icons.cloud_sync),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _githubRepoController,
            label: 'GitHub Repo',
            hint: 'username/repo-name',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _githubTokenController,
            label: 'GitHub Token',
            hint: 'Your GitHub personal access token',
            obscure: _obscureGitHub,
            onToggleObscure: () => setState(() => _obscureGitHub = !_obscureGitHub),
          ),
          const SizedBox(height: 16),

          // GitHub 연결 테스트 버튼
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isTesting ? null : _testGitHubConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.science, size: 20),
              label: Text(_isTesting ? '테스트 중...' : '연결 테스트'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF21262D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // 테스트 결과 표시
          if (_testResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('테스트 결과', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._testResults.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            r['ok'] == true ? Icons.check_circle : Icons.cancel,
                            size: 18,
                            color: r['ok'] == true ? const Color(0xFF7EE787) : const Color(0xFFF85149),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['step'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(
                                  r['msg'],
                                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Status
          _buildStatusCard(),

          const SizedBox(height: 24),

          // Debug 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showDebugInfo,
              icon: const Icon(Icons.bug_report, size: 20),
              label: const Text('디버그 정보 보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 디버그 정보 표시
  Future<void> _showDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // SharedPreferences에서 직접 읽기
    final rawToken = prefs.getString('github_token');
    final rawRepo = prefs.getString('github_repo');

    // ApiConfig 현재 값
    final configToken = ApiConfig.githubToken;
    final configRepo = ApiConfig.githubRepo;

    // 토큰 마스킹 (앞 10자, 뒤 4자만 표시)
    String maskToken(String? t) {
      if (t == null || t.isEmpty) return '(없음)';
      if (t.length <= 14) return '${t.substring(0, 4)}...';
      return '${t.substring(0, 10)}...${t.substring(t.length - 4)}';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('디버그 정보'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('[ SharedPreferences 직접 읽기 ]',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 8),
              Text('Token 길이: ${rawToken?.length ?? 0}'),
              Text('Token: ${maskToken(rawToken)}'),
              Text('Repo: ${rawRepo ?? "(없음)"}'),
              const SizedBox(height: 16),
              const Text('[ ApiConfig 현재 값 ]',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              Text('Token 길이: ${configToken?.length ?? 0}'),
              Text('Token: ${maskToken(configToken)}'),
              Text('Repo: ${configRepo ?? "(없음)"}'),
              const SizedBox(height: 16),
              const Text('[ 현재 입력 필드 ]',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 8),
              Text('Token 길이: ${_githubTokenController.text.length}'),
              Text('Token: ${maskToken(_githubTokenController.text)}'),
              Text('Repo: ${_githubRepoController.text}'),
              const SizedBox(height: 16),
              const Text('[ 비교 ]',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
              const SizedBox(height: 8),
              Text('SharedPrefs == ApiConfig: ${rawToken == configToken ? "✅ 일치" : "❌ 불일치"}'),
              Text('ApiConfig == 입력필드: ${configToken == _githubTokenController.text ? "✅ 일치" : "❌ 불일치"}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF58A6FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF58A6FF),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF161B22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }

  Widget _buildStatusCard() {
    final gitHubOk = _githubRepoController.text.isNotEmpty && _githubTokenController.text.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('상태', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatusRow('온디바이스 모드', _onDeviceMode),
            const SizedBox(height: 8),
            _buildStatusRow('GitHub Sync', gitHubOk),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: ok ? const Color(0xFF7EE787) : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          ok ? 'On' : 'Off',
          style: TextStyle(
            color: ok ? const Color(0xFF7EE787) : Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF7EE787))),
      ],
    );
  }
}

// ============================================================
// HOME SCREEN - 메인 화면
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.parksy.capture/share');

  String get _githubRepoUrl => ApiConfig.githubRepo != null
      ? 'https://github.com/${ApiConfig.githubRepo}/tree/main/logs'
      : '';

  // Logs tab state
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _showStarredOnly = false;
  String _searchQuery = '';
  String _sortBy = 'date';
  final TextEditingController _searchController = TextEditingController();

  // Tab controller
  late TabController _tabController;

  // Tools state
  bool _isExporting = false;
  String? _exportResult;

  // MCP Generator state
  bool _isGeneratingMCP = false;
  String? _mcpResult;

  // AI Search state
  final TextEditingController _aiQueryController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isAiSearching = false;
  String? _aiAnswer;
  List<Map<String, dynamic>> _aiReferences = [];
  String? _aiError;

  // Search mode: 'search' or 'generate'
  String _searchMode = 'search';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final logs = await platform.invokeMethod<List>('getLogFiles');
      final stats = await platform.invokeMethod<Map>('getStats');
      setState(() {
        _logs = logs?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _stats = Map<String, dynamic>.from(stats ?? {});
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var filtered = List<Map<String, dynamic>>.from(_logs);

    if (_showStarredOnly) {
      filtered = filtered.where((log) => log['starred'] == true).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((log) {
        final name = (log['name'] as String).toLowerCase();
        final preview = (log['preview'] as String? ?? '').toLowerCase();
        return name.contains(query) || preview.contains(query);
      }).toList();
    }

    switch (_sortBy) {
      case 'size':
        filtered.sort((a, b) => (b['size'] as int).compareTo(a['size'] as int));
        break;
      case 'name':
        filtered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        break;
      default:
        filtered.sort((a, b) => (b['modified'] as int).compareTo(a['modified'] as int));
    }

    _filteredLogs = filtered;
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _searchQuery = '';
      _applyFilters();
      setState(() {});
      return;
    }

    try {
      final results = await platform.invokeMethod<List>('searchLogs', {'query': query});
      setState(() {
        _filteredLogs = results?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _searchQuery = query;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  Future<void> _toggleStar(String filename, bool currentValue) async {
    await platform.invokeMethod('updateLogMeta', {
      'filename': filename,
      'starred': !currentValue,
    });
    _loadData();
  }

  Future<void> _deleteLog(String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Delete Log'),
        content: Text('Delete "$filename"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF85149)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await platform.invokeMethod('deleteLogFile', {'filename': filename});
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted')),
        );
      }
    }
  }

  Future<void> _openGitHub() async {
    if (_githubRepoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Repo not configured. Go to Settings.')),
      );
      return;
    }
    final uri = Uri.parse(_githubRepoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result == true) {
      setState(() {}); // Refresh to reflect new settings
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MM/dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLogsTab(),
                  _buildAiSearchTab(),
                  _buildToolsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openGitHub,
              backgroundColor: const Color(0xFF21262D),
              icon: const Icon(Icons.open_in_new, size: 20),
              label: const Text('View on GitHub'),
            )
          : null,
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          color: const Color(0xFF58A6FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: const Color(0xFF58A6FF),
        unselectedLabelColor: Colors.grey,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_outlined, size: 18),
                SizedBox(width: 8),
                Text('Logs'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.psychology_outlined, size: 18),
                SizedBox(width: 8),
                Text('AI'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build_outlined, size: 18),
                SizedBox(width: 8),
                Text('Tools'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        if (_stats.isNotEmpty) _buildStats(),
        _buildSearchBar(),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // JSONL 변환 섹션
          _buildSectionHeader('텍스트 변환기', Icons.transform),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.code, size: 20, color: Color(0xFF58A6FF)),
                      SizedBox(width: 8),
                      Text('로그 → JSONL 변환',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '저장된 로그를 LLAMA/GPT 파인튜닝 포맷으로 변환합니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportAllJsonl,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.file_download, size: 20),
                      label: Text(_isExporting ? '변환 중...' : '전체 JSONL 내보내기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF21262D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_exportResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Text(
                        _exportResult!,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // MCP 생성기 섹션 (Phase 3)
          _buildSectionHeader('워딩 프로파일러', Icons.person_search),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 20, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 8),
                      Text('박씨 워딩 프로파일',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '대화 로그를 분석하여 말투/워딩/성향 프로파일을 추출합니다.\nMCP 서버 자동 생성에 사용됩니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _generateProfile,
                      icon: const Icon(Icons.construction, size: 20),
                      label: const Text('프로파일 추출'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_exportResult != null && _exportResult!.contains('프로파일')) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Text(
                        _exportResult!,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // MCP 서버 생성기 섹션 (Phase 3-B)
          _buildSectionHeader('MCP 서버 생성기', Icons.dns),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal, size: 20, color: Color(0xFFF59E0B)),
                      SizedBox(width: 8),
                      Text('mcp-parksy-v1.js 생성',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '워딩 프로파일을 기반으로 박씨 전용 MCP 서버 코드를 생성합니다.\n'
                    '7번 위젯에 바로 배포 가능한 Node.js 서버입니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isGeneratingMCP ? null : _generateMCP,
                      icon: _isGeneratingMCP
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.dns, size: 20),
                      label: Text(_isGeneratingMCP ? '생성 중...' : 'MCP 서버 생성'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_mcpResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: SelectableText(
                        _mcpResult!,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 한국어↔영어 변환 (Phase 2-B)
          _buildSectionHeader('언어 변환기', Icons.translate),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.g_translate, size: 20, color: Color(0xFF7EE787)),
                      SizedBox(width: 8),
                      Text('한국어 ↔ 영어',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '저장된 로그를 영어 파인튜닝 데이터로 변환합니다.\n'
                    'ML Kit 온디바이스 번역 또는 MCP LLM 경유.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ML Kit 번역 — Google Play Services 필요')),
                        );
                      },
                      icon: const Icon(Icons.translate, size: 20),
                      label: const Text('영어 JSONL 변환'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7EE787),
                        side: const BorderSide(color: Color(0xFF7EE787)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 온디바이스 상태
          _buildSectionHeader('시스템 상태', Icons.memory),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.psychology, 'AI 엔진', '온디바이스 (로컬 텍스트 검색)'),
                  const SizedBox(height: 4),
                  _buildInfoRow(Icons.transform, '포맷 변환', 'JSONL 지원'),
                  const SizedBox(height: 4),
                  _buildInfoRow(Icons.cloud_off, '네트워크', '오프라인 작동'),
                  const SizedBox(height: 4),
                  _buildInfoRow(Icons.monetization_on, '비용', '과금 0원/월'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF7EE787))),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF58A6FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF58A6FF),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TOOLS FUNCTIONS
  // ============================================================

  Future<void> _exportAllJsonl() async {
    setState(() {
      _isExporting = true;
      _exportResult = null;
    });

    try {
      final results = await platform.invokeMethod<List>('convertAllToJsonl');
      if (results == null || results.isEmpty) {
        setState(() {
          _isExporting = false;
          _exportResult = '변환할 로그가 없습니다.';
        });
        return;
      }

      final sb = StringBuffer();
      int totalLines = 0;
      for (final r in results) {
        final map = Map<String, dynamic>.from(r);
        final name = map['filename'] as String? ?? 'unknown';
        final count = map['count'] as int? ?? 0;
        totalLines += count;
        sb.writeln('✅ $name  (${count}개 메시지 쌍)');
      }
      sb.writeln('\n총 ${results.length}개 파일, $totalLines개 메시지 쌍');

      setState(() {
        _isExporting = false;
        _exportResult = sb.toString();
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportResult = '오류: $e';
      });
    }
  }

  Future<void> _generateProfile() async {
    setState(() {
      _isExporting = true;
      _exportResult = null;
    });

    try {
      final result = await platform.invokeMethod<Map>('generateProfile');

      if (result == null || result.containsKey('error')) {
        setState(() {
          _isExporting = false;
          _exportResult = result?['error'] as String? ?? '프로파일 생성 실패';
        });
        return;
      }

      final profile = Map<String, dynamic>.from(result);
      final sb = StringBuffer();

      final isAI = profile['ai_analyzed'] == true;

      sb.writeln('📊 박씨 워딩 프로파일');
      sb.writeln('═══════════════════════');
      if (isAI) sb.writeln('🤖 AI 분석 (DeepSeek)');
      sb.writeln();

      if (isAI) {
        // === AI 기반 프로파일 포맷 ===
        final raw = profile['raw_profile'] as String?;
        if (raw != null) {
          sb.writeln(raw);
        } else {
          // 동사 패턴
          final verbPatterns = profile['verb_patterns'] as List<dynamic>? ?? [];
          if (verbPatterns.isNotEmpty) {
            sb.writeln('🔤 동사 패턴 (명령/지시형):');
            for (final v in verbPatterns) {
              final p = v as Map<String, dynamic>;
              sb.writeln('  • ${p['pattern']} (${p['count']}회) — ${p['context']}');
            }
            sb.writeln();
          }

          // 판단 표현
          final judgments = profile['judgment_expressions'] as List<dynamic>? ?? [];
          if (judgments.isNotEmpty) {
            sb.writeln('⚖️  판단/확인 표현:');
            for (final j in judgments) {
              final jm = j as Map<String, dynamic>;
              sb.writeln('  • ${jm['expression']} (${jm['count']}회) — ${jm['context']}');
            }
            sb.writeln();
          }

          // 의사결정 패턴
          final decisions = profile['decision_patterns'] as List<dynamic>? ?? [];
          if (decisions.isNotEmpty) {
            sb.writeln('🧠 의사결정 패턴:');
            for (final d in decisions) {
              final dm = d as Map<String, dynamic>;
              sb.writeln('  • ${dm['pattern']} (${dm['count']}회)');
              if (dm['example'] != null) sb.writeln('    예: ${dm['example']}');
            }
            sb.writeln();
          }

          // 도메인 용어
          final terms = profile['domain_terminology'] as List<dynamic>? ?? [];
          if (terms.isNotEmpty) {
            sb.writeln('📁 도메인 용어:');
            for (final t in terms) {
              final tm = t as Map<String, dynamic>;
              sb.writeln('  • ${tm['term']} (${tm['count']}회, ${tm['category'] ?? "?"})');
            }
            sb.writeln();
          }

          // 말투 스펙트럼
          final tone = profile['tone_spectrum'] as Map<String, dynamic>? ?? {};
          if (tone.isNotEmpty) {
            sb.writeln('🎭 말투 스펙트럼:');
            final toneList = tone.entries.toList()
              ..sort((a, b) => (b.value as num).compareTo(a.value as num));
            for (final entry in toneList) {
              final pct = ((entry.value as num) * 100).toStringAsFixed(0);
              final label = switch (entry.key) {
                'direct_command' => '직접 명령',
                'casual_question' => '편한 질문',
                'formal_statement' => '격식 진술',
                _ => entry.key,
              };
              sb.writeln('  • $label: $pct%');
            }
            sb.writeln();
          }

          // 커뮤니케이션 스타일
          final style = profile['communication_style'] as Map<String, dynamic>? ?? {};
          if (style.isNotEmpty) {
            sb.writeln('💬 커뮤니케이션 스타일:');
            sb.writeln('  • 문장 길이: ${style['avg_sentence_length'] ?? "?"}');
            sb.writeln('  • 이모지 사용: ${style['emoji_usage'] ?? "?"}');
            sb.writeln('  • 타이핑 스타일: ${style['typing_style'] ?? "?"}');
            sb.writeln('  • 격식 수준: ${style['formality'] ?? "?"}');
            final phrases = style['key_phrases'] as List<dynamic>? ?? [];
            if (phrases.isNotEmpty) {
              sb.writeln('  • 핵심 구문: ${phrases.join(", ")}');
            }
            sb.writeln();
          }

          // 액션 트리거
          final triggers = profile['action_triggers'] as List<dynamic>? ?? [];
          if (triggers.isNotEmpty) {
            sb.writeln('🚀 액션 트리거:');
            for (final t in triggers) {
              final tm = t as Map<String, dynamic>;
              sb.writeln('  • "${tm['trigger']}" → ${tm['intent']} (${tm['frequency']})');
            }
            sb.writeln();
          }

          // 추천 MCP 도구
          final tools = profile['recommended_mcp_tools'] as List<dynamic>? ?? [];
          if (tools.isNotEmpty) {
            sb.writeln('🛠️  추천 MCP 도구:');
            for (final t in tools) {
              final tm = t as Map<String, dynamic>;
              sb.writeln('  • ${tm['name']}: ${tm['description']} (trigger: ${tm['trigger']})');
            }
            sb.writeln();
          }
        }

        // 날짜 범위 (공통)
        final dates = profile['date_range'] as Map<String, dynamic>? ?? {};
        if (dates.isNotEmpty) {
          sb.writeln('📅 분석 기간: ${dates['earliest']} ~ ${dates['latest']}');
          sb.writeln('📁 로그 파일: ${profile['total_logs']}개');
        }
      } else {
        // === 규칙 기반 프로파일 포맷 (fallback) ===
        final vocab = profile['vocabulary'] as Map<String, dynamic>? ?? {};
        final freqTerms = (vocab['frequent_terms'] as List<dynamic>?) ?? [];
        sb.writeln('🔤 자주 사용하는 단어 (${vocab['total_unique_words']}개 고유 단어):');
        for (final word in freqTerms.take(15)) {
          sb.writeln('  • $word');
        }

        final patterns = (vocab['sentence_patterns'] as List<dynamic>?) ?? [];
        if (patterns.isNotEmpty) {
          sb.writeln();
          sb.writeln('💬 문장 패턴:');
          for (final p in patterns) {
            sb.writeln('  • $p');
          }
        }

        final domains = profile['domain_weights'] as Map<String, dynamic>? ?? {};
        if (domains.isNotEmpty) {
          sb.writeln();
          sb.writeln('📁 기술 도메인:');
          final domainList = domains.entries.toList()
            ..sort((a, b) => (b.value as num).compareTo(a.value as num));
          for (final entry in domainList) {
            final pct = ((entry.value as num) * 100).toStringAsFixed(0);
            sb.writeln('  • ${entry.key}: $pct%');
          }
        }

        final stats = profile['conversation_stats'] as Map<String, dynamic>? ?? {};
        sb.writeln();
        sb.writeln('📐 대화 통계:');
        sb.writeln('  • 총 턴: ${profile['total_turns']}');
        sb.writeln('  • User 길이: ${(stats['avg_user_tokens'] as num?)?.toStringAsFixed(0) ?? "?"}자');
        sb.writeln('  • Assistant 길이: ${(stats['avg_assistant_tokens'] as num?)?.toStringAsFixed(0) ?? "?"}자');

        final dates = profile['date_range'] as Map<String, dynamic>? ?? {};
        sb.writeln('  • 기간: ${dates['earliest']} ~ ${dates['latest']}');
      }

      setState(() {
        _isExporting = false;
        _exportResult = sb.toString();
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportResult = '프로파일 오류: $e';
      });
    }
  }

  /// MCP 서버 코드 생성 (DeepSeek API 경유)
  Future<void> _generateMCP() async {
    setState(() {
      _isGeneratingMCP = true;
      _mcpResult = null;
    });

    try {
      // 먼저 프로파일 추출
      final profile = await platform.invokeMethod<Map>('generateProfile');
      if (profile == null || profile.containsKey('error')) {
        setState(() {
          _isGeneratingMCP = false;
          _mcpResult = profile?['error'] as String? ?? '프로파일이 없습니다. 먼저 프로파일을 추출해주세요.';
        });
        return;
      }

      // 프로파일을 JSON 문자열로 변환
      final profileJson = jsonEncode(profile);

      // MCP 생성 요청
      final code = await platform.invokeMethod<String>('generateMCP', {
        'profile': profileJson,
      }).timeout(const Duration(seconds: 35));

      setState(() {
        _isGeneratingMCP = false;
        _mcpResult = code ?? '생성 실패';
      });
    } catch (e) {
      setState(() {
        _isGeneratingMCP = false;
        _mcpResult = 'MCP 생성 오류: Embed Server(:8018)가 실행 중인지 확인하세요.\n$e';
      });
    }
  }

  Widget _buildAiSearchTab() {
    if (!ApiConfig.isAiConfigured) {
      return _buildAiNotConfigured();
    }

    return Column(
      children: [
        _buildAiSearchInput(),
        _buildSearchModeSelector(),
        _buildAiSearchButton(),
        Expanded(child: _buildAiResult()),
      ],
    );
  }

  Widget _buildAiNotConfigured() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 24),
            const Text(
              '온디바이스 AI 검색',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '인터넷 없이 로컬에서 검색합니다.\nNPU 가속 지원 · 과금 0원',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSearchInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _aiQueryController,
              decoration: InputDecoration(
                hintText: '무엇이든 물어보세요...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _aiQueryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _aiQueryController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _askAi(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _isListening ? const Color(0xFFF85149).withOpacity(0.2) : const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isListening ? const Color(0xFFF85149) : const Color(0xFF30363D),
              ),
            ),
            child: IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? const Color(0xFFF85149) : Colors.grey,
              ),
              onPressed: _toggleVoiceInput,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              'search',
              '검색',
              Icons.search,
              '관련 기록 찾아서 요약',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeButton(
              'generate',
              '종합 생성',
              Icons.auto_awesome,
              '자료 모아서 새 글 생성',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon, String desc) {
    final isSelected = _searchMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _searchMode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF58A6FF).withOpacity(0.15) : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isSelected ? const Color(0xFF58A6FF) : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF58A6FF) : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSearchButton() {
    final buttonLabel = _searchMode == 'search' ? 'AI한테 물어보기' : '종합 생성하기';
    final buttonIcon = _searchMode == 'search' ? Icons.psychology : Icons.auto_awesome;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isAiSearching || _aiQueryController.text.isEmpty ? null : _askAi,
          icon: _isAiSearching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(buttonIcon, size: 20),
          label: Text(_isAiSearching ? '처리 중...' : buttonLabel),
          style: ElevatedButton.styleFrom(
            backgroundColor: _searchMode == 'search'
                ? const Color(0xFF238636)
                : const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF21262D),
            disabledForegroundColor: Colors.grey,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildAiResult() {
    if (_isAiSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _searchMode == 'search' ? const Color(0xFF58A6FF) : const Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 16),
            Text(
              _searchMode == 'search' ? '기록을 검색하고 있어요...' : '종합 글을 생성하고 있어요...',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_aiError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFF85149)),
            const SizedBox(height: 16),
            Text(_aiError!, style: const TextStyle(color: Color(0xFFF85149))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _aiError = null),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_aiAnswer == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text('질문을 입력하세요', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              _searchMode == 'search'
                  ? '과거 기록에서 답을 찾아드려요'
                  : '관련 자료를 모아 새 글을 생성해요',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Answer card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _searchMode == 'search' ? Icons.auto_awesome : Icons.article,
                        size: 18,
                        color: _searchMode == 'search' ? const Color(0xFF58A6FF) : const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _searchMode == 'search' ? 'AI 답변' : '종합 생성 결과',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _searchMode == 'search' ? const Color(0xFF58A6FF) : const Color(0xFF8B5CF6),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _aiAnswer!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _aiAnswer!,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                ],
              ),
            ),
          ),

          if (_aiReferences.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '참조한 기록 (${_aiReferences.length}개)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...(_aiReferences.map((ref) {
              final metadata = ref['metadata'] as Map<String, dynamic>? ?? {};
              final date = metadata['date']?.toString() ?? 'Unknown';
              final speaker = metadata['speaker']?.toString() ?? 'unknown';
              final similarity = ((ref['similarity'] as num?) ?? 0).toStringAsFixed(2);
              final content = (ref['content'] as String?) ?? '';
              final preview = content.length > 100 ? '${content.substring(0, 100)}...' : content;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    speaker == 'user' ? Icons.person : Icons.smart_toy,
                    color: speaker == 'user' ? const Color(0xFF7EE787) : const Color(0xFF58A6FF),
                    size: 20,
                  ),
                  title: Text(
                    date,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  trailing: Text(
                    similarity,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              );
            })),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // AI SEARCH API FUNCTIONS
  // ============================================================

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          setState(() => _isListening = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('음성 인식 오류: ${error.errorMsg}')),
            );
          }
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _aiQueryController.text = result.recognizedWords;
            });
          },
          localeId: 'ko_KR',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('음성 인식을 사용할 수 없습니다')),
          );
        }
      }
    }
  }

  Future<void> _askAi() async {
    final query = _aiQueryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isAiSearching = true;
      _aiError = null;
      _aiAnswer = null;
      _aiReferences = [];
    });

    try {
      if (ApiConfig.onDeviceMode) {
        // 온디바이스 검색: Kotlin MethodChannel → 로컬 검색
        final result = await platform.invokeMethod<Map>('onDeviceSearch', {
          'query': query,
          'mode': _searchMode,
        }).timeout(const Duration(seconds: 30));

        setState(() {
          _isAiSearching = false;
          _aiAnswer = result?['answer'] as String? ?? '결과 없음';
          _aiReferences = (result?['references'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ?? [];
        });
      } else {
        // GitHub 모드: 기존 파일 검색만
        final searchResults = await platform.invokeMethod<List>('searchLogs', {'query': query});
        final refs = searchResults?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        setState(() {
          _isAiSearching = false;
          _aiAnswer = refs.isEmpty
              ? '관련 기록을 찾을 수 없습니다.'
              : '${refs.length}개의 관련 기록을 찾았습니다.';
          _aiReferences = refs;
        });
      }
    } catch (e) {
      setState(() {
        _isAiSearching = false;
        _aiError = e.toString();
      });
    }
  }

  // ============================================================
  // LOGS TAB UI
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.catching_pokemon, color: Color(0xFF58A6FF), size: 28),
          const SizedBox(width: 12),
          const Text(
            'Parksy Capture',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAbout(),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final total = _stats['totalLogs'] ?? 0;
    final starred = _stats['starredCount'] ?? 0;
    final size = _formatSize(_stats['totalSize'] ?? 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Logs', value: '$total'),
          _StatItem(label: 'Starred', value: '$starred'),
          _StatItem(label: 'Size', value: size),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => _search(value),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _showStarredOnly ? const Color(0xFF58A6FF).withOpacity(0.2) : const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showStarredOnly ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
              ),
            ),
            child: IconButton(
              icon: Icon(
                _showStarredOnly ? Icons.star : Icons.star_border,
                color: _showStarredOnly ? const Color(0xFF58A6FF) : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _showStarredOnly = !_showStarredOnly;
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            color: const Color(0xFF161B22),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _applyFilters();
              });
            },
            itemBuilder: (context) => [
              _buildSortItem('date', 'Date', Icons.schedule),
              _buildSortItem('size', 'Size', Icons.storage),
              _buildSortItem('name', 'Name', Icons.sort_by_alpha),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? const Color(0xFF58A6FF) : Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isSelected ? const Color(0xFF58A6FF) : Colors.white)),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18, color: Color(0xFF58A6FF)),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No results found' : 'No logs yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Share text from browser to capture',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF58A6FF),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredLogs.length,
        itemBuilder: (context, index) => _buildLogCard(_filteredLogs[index]),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final name = log['name'] as String;
    final size = log['size'] as int;
    final modified = log['modified'] as int;
    final preview = log['preview'] as String? ?? '';
    final starred = log['starred'] as bool? ?? false;

    final displayName = name.replaceAll('ParksyLog_', '').replaceAll('.md', '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LogDetailScreen(filename: name)),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleStar(name, starred),
                    child: Icon(
                      starred ? Icons.star : Icons.star_border,
                      color: starred ? Colors.amber : Colors.grey[600],
                      size: 22,
                    ),
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(modified),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.storage, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatSize(size),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _deleteLog(name),
                    child: Icon(Icons.delete_outline, size: 20, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            const Icon(Icons.catching_pokemon, color: Color(0xFF58A6FF)),
            const SizedBox(width: 12),
            const Text('Parksy Capture'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version 10.0.5'),
            const SizedBox(height: 16),
            Text(
              'Lossless conversation capture for LLM power users.\n\n'
              'When copy-paste fails, share to capture.',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF58A6FF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

// ============================================================
// LOG DETAIL SCREEN
// ============================================================

class LogDetailScreen extends StatefulWidget {
  final String filename;

  const LogDetailScreen({super.key, required this.filename});

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  static const platform = MethodChannel('com.parksy.capture/share');
  String? _content;
  bool _isLoading = true;
  bool _starred = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await platform.invokeMethod<String>(
        'readLogFile',
        {'filename': widget.filename},
      );
      final meta = await platform.invokeMethod<Map>(
        'getLogMeta',
        {'filename': widget.filename},
      );
      setState(() {
        _content = content;
        _starred = meta?['starred'] as bool? ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _extractBody(String content) {
    final lines = content.split('\n');
    int startIndex = 0;
    if (lines.isNotEmpty && lines[0].trim() == '---') {
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') {
          startIndex = i + 1;
          break;
        }
      }
    }
    return lines.skip(startIndex).join('\n').trim();
  }

  Future<void> _toggleStar() async {
    await platform.invokeMethod('updateLogMeta', {
      'filename': widget.filename,
      'starred': !_starred,
    });
    setState(() => _starred = !_starred);
  }

  Future<void> _openOnGitHub() async {
    if (ApiConfig.githubRepo == null || ApiConfig.githubRepo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Repo not configured. Go to Settings.')),
      );
      return;
    }
    final match = RegExp(r'ParksyLog_(\d{4})(\d{2})').firstMatch(widget.filename);
    String path = 'logs';
    if (match != null) {
      final year = match.group(1);
      final month = match.group(2);
      path = 'logs/$year/$month';
    }
    final url = 'https://github.com/${ApiConfig.githubRepo}/tree/main/$path';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyToClipboard() async {
    if (_content == null) return;
    final body = _extractBody(_content!);
    await Clipboard.setData(ClipboardData(text: body));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  Future<void> _playTts() async {
    if (_content == null) return;
    if (_isPlaying) {
      await platform.invokeMethod('stopSpeaking');
      setState(() => _isPlaying = false);
      return;
    }
    final body = _extractBody(_content!);
    // 앞부분 3000자로 제한 (Android TTS timeout 방지)
    final text = body.length > 3000 ? body.substring(0, 3000) : body;
    await platform.invokeMethod('speakText', {'text': text});
    setState(() => _isPlaying = true);
    // 30초 후 자동 리셋 (재생 완료 추정)
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _isPlaying) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.filename.replaceAll('ParksyLog_', '').replaceAll('.md', '');

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')),
        actions: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow,
                        color: _isPlaying ? Colors.greenAccent : null),
            onPressed: _content != null ? _playTts : null,
          ),
          IconButton(
            icon: Icon(_starred ? Icons.star : Icons.star_border, color: _starred ? Colors.amber : null),
            onPressed: _toggleStar,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _content != null ? _copyToClipboard : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _content == null
              ? const Center(child: Text('Failed to load'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(
                    _extractBody(_content!),
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openOnGitHub,
        backgroundColor: const Color(0xFF21262D),
        icon: const Icon(Icons.open_in_new, size: 20),
        label: const Text('View on GitHub'),
      ),
    );
  }
}
