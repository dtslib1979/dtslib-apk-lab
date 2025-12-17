import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  runApp(const CaptureApp());
}

class CaptureApp extends StatelessWidget {
  const CaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Capture',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const AppRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 앱 시작 시 실행 모드에 따라 라우팅
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  static const platform = MethodChannel('com.parksy.capture/share');
  bool _isLoading = true;
  bool _isShareIntent = false;

  @override
  void initState() {
    super.initState();
    _checkLaunchMode();
  }

  Future<void> _checkLaunchMode() async {
    try {
      final isShare = await platform.invokeMethod<bool>('isShareIntent');
      setState(() {
        _isShareIntent = isShare ?? false;
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
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_isShareIntent) {
      return const ShareHandler();
    } else {
      return const LogListScreen();
    }
  }
}

/// 공유 Intent 처리 (기존 기능)
class ShareHandler extends StatefulWidget {
  const ShareHandler({super.key});

  @override
  State<ShareHandler> createState() => _ShareHandlerState();
}

class _ShareHandlerState extends State<ShareHandler> {
  static const platform = MethodChannel('com.parksy.capture/share');
  
  static const workerUrl = String.fromEnvironment('PARKSY_WORKER_URL', defaultValue: '');
  static const apiKey = String.fromEnvironment('PARKSY_API_KEY', defaultValue: '');
  static final cloudEnabled = workerUrl.isNotEmpty && apiKey.isNotEmpty;

  String _statusMessage = 'Processing...';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleShare();
    });
  }

  Future<void> _handleShare() async {
    try {
      final text = await platform.invokeMethod<String>('getSharedText');
      if (text == null || text.isEmpty) {
        _showToast('No text received');
        _finish();
        return;
      }
      
      if (text.length > 100000) {
        debugPrint('Warning: Large text received (${text.length} chars)');
      }
      
      final localOk = await _saveLocal(text);
      if (!localOk) {
        _showToast('Save Failed ❌');
        _finish();
        return;
      }
      
      if (!cloudEnabled) {
        _showToast('Saved locally ✅');
        _finish();
        return;
      }
      
      final cloudOk = await _saveCloud(text);
      if (cloudOk) {
        _showToast('Saved Local & Cloud 🚀');
      } else {
        _showToast('Saved locally ✅ (cloud failed)');
      }
      
      _finish();
    } catch (e) {
      debugPrint('Share handler error: $e');
      _showToast('Error: $e');
      _finish();
    }
  }

  Future<bool> _saveLocal(String text) async {
    try {
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fname = 'ParksyLog_$ts.md';
      final content = _toMarkdown(text);
      
      final result = await platform.invokeMethod<bool>(
        'saveToDownloads',
        {'filename': fname, 'content': content},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Local save error: $e');
      return false;
    }
  }

  Future<bool> _saveCloud(String text) async {
    try {
      final ts = DateTime.now().toIso8601String();
      final res = await http.post(
        Uri.parse(workerUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode({
          'text': text,
          'source': 'android',
          'ts': ts,
        }),
      ).timeout(const Duration(seconds: 5));
      
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Cloud save error: $e');
      return false;
    }
  }

  String _toMarkdown(String text) {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return '''---
date: $ts
source: android-share
---

$text
''';
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _statusMessage = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
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
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusMessage),
          ],
        ),
      ),
    );
  }
}

/// 저장된 로그 목록 화면
class LogListScreen extends StatefulWidget {
  const LogListScreen({super.key});

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  static const platform = MethodChannel('com.parksy.capture/share');
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final result = await platform.invokeMethod<List>('getLogFiles');
      setState(() {
        _logs = result?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load logs error: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MM/dd HH:mm').format(date);
  }

  Future<void> _deleteLog(String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Log'),
        content: Text('Delete "$filename"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await platform.invokeMethod('deleteLogFile', {'filename': filename});
      _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parksy Capture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No logs yet', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text(
                        'Share text from browser to capture',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final name = log['name'] as String;
                      final size = log['size'] as int;
                      final modified = log['modified'] as int;
                      
                      return ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(
                          name.replaceAll('ParksyLog_', '').replaceAll('.md', ''),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        subtitle: Text('${_formatFileSize(size)} • ${_formatDate(modified)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => _deleteLog(name),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LogDetailScreen(filename: name),
                            ),
                          ).then((_) => _loadLogs());
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

/// 로그 상세 보기 + 공유 화면
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
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Read log error: $e');
      setState(() => _isLoading = false);
    }
  }

  String _extractBody(String content) {
    // YAML frontmatter 제거
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

  Future<void> _shareContent() async {
    if (_content == null) return;
    
    final body = _extractBody(_content!);
    await platform.invokeMethod('shareText', {
      'text': body,
      'title': 'Share Log',
    });
  }

  Future<void> _copyToClipboard() async {
    if (_content == null) return;
    
    final body = _extractBody(_content!);
    await Clipboard.setData(ClipboardData(text: body));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard ✅'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.filename.replaceAll('ParksyLog_', '').replaceAll('.md', ''),
          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to Clipboard',
            onPressed: _content != null ? _copyToClipboard : null,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _content != null ? _shareContent : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _content == null
              ? const Center(child: Text('Failed to load'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _extractBody(_content!),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _content != null ? _shareContent : null,
        icon: const Icon(Icons.upload),
        label: const Text('Upload to LLM'),
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
      ),
    );
  }
}
