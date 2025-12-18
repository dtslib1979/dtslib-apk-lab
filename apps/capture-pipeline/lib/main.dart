import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

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
    _checkLaunchMode();
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
  
  static const _githubToken = String.fromEnvironment('PARKSY_GITHUB_TOKEN', defaultValue: '');
  static const _githubRepo = 'dtslib1979/parksy-logs';
  static final _syncEnabled = _githubToken.isNotEmpty;

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

      if (!_syncEnabled) {
        _updateStatus('Saved ✓', Icons.check_circle, const Color(0xFF7EE787));
        _finish();
        return;
      }

      setState(() {
        _status = 'Syncing to GitHub...';
        _icon = Icons.cloud_upload;
      });

      final cloudOk = await _syncToGitHub(fname, content);
      if (cloudOk) {
        _updateStatus('Saved & Synced ✓', Icons.cloud_done, const Color(0xFF7EE787));
      } else {
        _updateStatus('Saved locally ✓', Icons.check_circle, const Color(0xFF7EE787));
      }
      
      _finish();
    } catch (e) {
      _updateStatus('Error: $e', Icons.error, const Color(0xFFF85149));
      _finish();
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

  Future<bool> _syncToGitHub(String filename, String content) async {
    try {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final path = 'logs/$year/$month/$filename';
      
      final url = 'https://api.github.com/repos/$_githubRepo/contents/$path';
      
      final res = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': 'Add $filename',
          'content': base64Encode(utf8.encode(content)),
        }),
      ).timeout(const Duration(seconds: 10));
      
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (e) {
      debugPrint('GitHub sync failed: $e');
      return false;
    }
  }

  String _toMarkdown(String text) {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return '---\ndate: $ts\nsource: android-share\n---\n\n$text\n';
  }

  void _finish() {
    Future.delayed(const Duration(seconds: 2), () {
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
// HOME SCREEN - 메인 화면
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.parksy.capture/share');
  static const _githubRepoUrl = 'https://github.com/dtslib1979/parksy-logs/tree/main/logs';
  
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _showStarredOnly = false;
  String _searchQuery = '';
  String _sortBy = 'date';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
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
    final uri = Uri.parse(_githubRepoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            if (_stats.isNotEmpty) _buildStats(),
            _buildSearchBar(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGitHub,
        backgroundColor: const Color(0xFF21262D),
        icon: const Icon(Icons.open_in_new, size: 20),
        label: const Text('View on GitHub'),
      ),
    );
  }

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
            const Text('Version 5.0.0'),
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
    final match = RegExp(r'ParksyLog_(\d{4})(\d{2})').firstMatch(widget.filename);
    String path = 'logs';
    if (match != null) {
      final year = match.group(1);
      final month = match.group(2);
      path = 'logs/$year/$month';
    }
    final url = 'https://github.com/dtslib1979/parksy-logs/tree/main/$path';
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
        const SnackBar(content: Text('Copied to clipboard ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.filename.replaceAll('ParksyLog_', '').replaceAll('.md', '');

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')),
        actions: [
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
