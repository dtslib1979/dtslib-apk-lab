import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const CaptureLiteApp());
}

class CaptureLiteApp extends StatelessWidget {
  const CaptureLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Capture Lite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CaptureLog {
  final String id;
  final String content;
  final DateTime timestamp;
  final String? source;

  CaptureLog({
    required this.id,
    required this.content,
    required this.timestamp,
    this.source,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
      };

  factory CaptureLog.fromJson(Map<String, dynamic> json) => CaptureLog(
        id: json['id'],
        content: json['content'],
        timestamp: DateTime.parse(json['timestamp']),
        source: json['source'],
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CaptureLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _setupShareIntent();
  }

  void _setupShareIntent() {
    // Handle incoming shared text when app is opened
    ReceiveSharingIntent.getInitialText().then((String? text) {
      if (text != null && text.isNotEmpty) {
        _saveNewLog(text);
      }
    });

    // Handle incoming shared text while app is running
    ReceiveSharingIntent.getTextStream().listen((String text) {
      if (text.isNotEmpty) {
        _saveNewLog(text);
      }
    });
  }

  Future<Directory> _getStorageDirectory() async {
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      final captureDir = Directory('${extDir.path}/CaptureLite');
      if (!await captureDir.exists()) {
        await captureDir.create(recursive: true);
      }
      return captureDir;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final captureDir = Directory('${docDir.path}/CaptureLite');
    if (!await captureDir.exists()) {
      await captureDir.create(recursive: true);
    }
    return captureDir;
  }

  Future<File> _getLogsFile() async {
    final dir = await _getStorageDirectory();
    return File('${dir.path}/logs.json');
  }

  Future<void> _loadLogs() async {
    try {
      final file = await _getLogsFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr);
        setState(() {
          _logs = jsonList.map((j) => CaptureLog.fromJson(j)).toList();
          _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _isLoading = false;
        });
      } else {
        setState(() {
          _logs = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _logs = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLogs() async {
    final file = await _getLogsFile();
    final jsonStr = json.encode(_logs.map((l) => l.toJson()).toList());
    await file.writeAsString(jsonStr);
  }

  Future<void> _saveNewLog(String content) async {
    final log = CaptureLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      timestamp: DateTime.now(),
      source: 'shared',
    );
    setState(() {
      _logs.insert(0, log);
    });
    await _saveLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('텍스트가 저장되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteLog(CaptureLog log) async {
    setState(() {
      _logs.removeWhere((l) => l.id == log.id);
    });
    await _saveLogs();
  }

  void _showLogDetail(CaptureLog log) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogDetailScreen(
          log: log,
          onDelete: () {
            _deleteLog(log);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Parksy Capture Lite'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? _buildEmptyState()
              : _buildLogList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.content_paste_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            '저장된 텍스트가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 앱에서 텍스트를 공유하거나\n+ 버튼으로 직접 추가하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildLogCard(CaptureLog log) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          log.content.length > 100
              ? '${log.content.substring(0, 100)}...'
              : log.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          dateFormat.format(log.timestamp),
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () => _copyToClipboard(log.content),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _confirmDelete(log),
            ),
          ],
        ),
        onTap: () => _showLogDetail(log),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('클립보드에 복사되었습니다'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _confirmDelete(CaptureLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLog(log);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('텍스트 추가'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '텍스트를 입력하세요...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _saveNewLog(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class LogDetailScreen extends StatelessWidget {
  final CaptureLog log;
  final VoidCallback onDelete;

  const LogDetailScreen({
    super.key,
    required this.log,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 보기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('클립보드에 복사되었습니다'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(log.content),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('삭제'),
                  content: const Text('이 항목을 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(log.timestamp),
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              log.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
