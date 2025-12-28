import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TTSFactoryApp());
}

class TTSFactoryApp extends StatelessWidget {
  const TTSFactoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTS Factory',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      home: const HomeScreen(),
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
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _serverUrl = '';
  String _appSecret = '';
  bool _isLoading = true;

  final List<TTSItem> _items = [];
  String _preset = 'neutral';
  String? _currentJobId;
  JobStatus _jobStatus = JobStatus.idle;
  int _progress = 0;
  int _total = 0;
  Timer? _pollTimer;
  String? _lastDownloadPath;

  final _presets = {
    'neutral': 'Neutral',
    'calm': 'Calm',
    'bright': 'Bright',
  };

  // Download folder path
  static const _downloadBasePath = '/storage/emulated/0/Download/TTS-Factory';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _ensureDownloadFolder();
  }

  Future<void> _ensureDownloadFolder() async {
    final dir = Directory(_downloadBasePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('tts_server_url') ?? '';
      _appSecret = prefs.getString('tts_app_secret') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings(String url, String secret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tts_server_url', url);
    await prefs.setString('tts_app_secret', secret);
    setState(() {
      _serverUrl = url;
      _appSecret = secret;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _parseContent(data.text!);
    } else {
      _showError('Clipboard is empty');
    }
  }

  void _parseContent(String content) {
    final lines = content.split('\n');
    final items = <TTSItem>[];
    int idx = 1;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.length > 1100) {
        _showError('Item $idx exceeds 1100 chars');
        return;
      }
      items.add(TTSItem(
        id: idx.toString().padLeft(2, '0'),
        text: trimmed,
      ));
      idx++;
    }

    if (items.length > 25) {
      _showError('Max 25 items allowed');
      return;
    }

    setState(() {
      _items.clear();
      _items.addAll(items);
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFF85149),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF238636),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _startJob() async {
    if (_items.isEmpty) {
      _showError('No items');
      return;
    }

    if (_serverUrl.isEmpty || _appSecret.isEmpty) {
      _showError('Server not configured - tap Settings');
      return;
    }

    setState(() => _jobStatus = JobStatus.queued);

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/v1/jobs'),
        headers: {
          'Content-Type': 'application/json',
          'x-app-secret': _appSecret,
        },
        body: jsonEncode({
          'batch_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'preset': _preset,
          'items': _items.map((e) => {
            'id': e.id,
            'text': e.text,
            'max_chars': 1100,
          }).toList(),
        }),
      );

      if (response.statusCode == 202) {
        final data = jsonDecode(response.body);
        _currentJobId = data['job_id'];
        setState(() {
          _jobStatus = JobStatus.processing;
          _total = _items.length;
        });
        _startPolling();
      } else {
        _showError('Failed: ${response.statusCode}');
        setState(() => _jobStatus = JobStatus.idle);
      }
    } catch (e) {
      _showError('Network error: $e');
      setState(() => _jobStatus = JobStatus.idle);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollStatus(),
    );
  }

  Future<void> _pollStatus() async {
    if (_currentJobId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/v1/jobs/$_currentJobId'),
        headers: {'x-app-secret': _appSecret},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _progress = data['progress'] ?? 0;
          _total = data['total'] ?? _items.length;
        });

        if (data['status'] == 'completed') {
          _pollTimer?.cancel();
          await _downloadResult();
        } else if (data['status'] == 'failed') {
          _pollTimer?.cancel();
          _showError('Job failed: ${data['error'] ?? 'Unknown error'}');
          setState(() => _jobStatus = JobStatus.idle);
        }
      }
    } catch (e) {
      debugPrint('Poll error: $e');
    }
  }

  Future<void> _downloadResult() async {
    if (_currentJobId == null) return;

    setState(() => _jobStatus = JobStatus.downloading);

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/v1/jobs/$_currentJobId/download'),
        headers: {'x-app-secret': _appSecret},
      );

      if (response.statusCode == 200) {
        await _ensureDownloadFolder();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'tts_$timestamp.zip';
        final file = File('$_downloadBasePath/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        _lastDownloadPath = file.path;
        _showSuccess('Downloaded to Download/TTS-Factory/$fileName');

        setState(() {
          _jobStatus = JobStatus.idle;
          _currentJobId = null;
          _progress = 0;
          _items.clear();
        });
      } else {
        _showError('Download failed: ${response.statusCode}');
        setState(() => _jobStatus = JobStatus.idle);
      }
    } catch (e) {
      _showError('Download error: $e');
      setState(() => _jobStatus = JobStatus.idle);
    }
  }

  void _openSettings() {
    final urlController = TextEditingController(text: _serverUrl);
    final secretController = TextEditingController(text: _appSecret);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(
          children: [
            Icon(Icons.settings, size: 24),
            SizedBox(width: 12),
            Text('Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://your-tts-server.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: secretController,
              decoration: const InputDecoration(
                labelText: 'App Secret',
                hintText: 'your-secret-key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.folder, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Download: /Download/TTS-Factory/',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveSettings(
                urlController.text.trim(),
                secretController.text.trim(),
              );
              Navigator.pop(ctx);
              _showSuccess('Settings saved');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.mic, size: 28),
            SizedBox(width: 12),
            Text('TTS Factory'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: _serverUrl.isEmpty ? Colors.orange : Colors.grey,
            ),
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAbout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_serverUrl.isEmpty) _buildSetupBanner(),
            _buildPresetSelector(),
            _buildStatus(),
            Expanded(child: _buildItemList()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildSetupBanner() {
    return GestureDetector(
      onTap: _openSettings,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap here to configure server URL',
                style: TextStyle(color: Colors.orange),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          const Text('Voice:', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.entries.map((e) => ChoiceChip(
                label: Text(e.value),
                selected: _preset == e.key,
                onSelected: _jobStatus == JobStatus.idle
                    ? (sel) {
                        if (sel) setState(() => _preset = e.key);
                      }
                    : null,
                selectedColor: const Color(0xFF58A6FF).withValues(alpha: 0.3),
                backgroundColor: const Color(0xFF21262D),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    if (_jobStatus == JobStatus.idle) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(label: 'Items', value: '${_items.length}'),
            const _StatItem(label: 'Max', value: '25'),
            _StatItem(
              label: 'Chars',
              value: _items.isEmpty
                  ? '0'
                  : '${_items.map((e) => e.text.length).reduce((a, b) => a + b)}',
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _jobStatus.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('$_progress / $_total'),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _total > 0 ? _progress / _total : null,
            backgroundColor: const Color(0xFF30363D),
            color: const Color(0xFF58A6FF),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.content_paste, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Paste text to start',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Each line = one TTS item',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF21262D),
              child: Text(
                item.id,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            title: Text(
              item.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            trailing: Text(
              '${item.text.length}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildFAB() {
    if (_jobStatus != JobStatus.idle) return null;

    if (_items.isEmpty) {
      return FloatingActionButton.extended(
        onPressed: _pasteFromClipboard,
        backgroundColor: const Color(0xFF238636),
        icon: const Icon(Icons.content_paste),
        label: const Text('Paste'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'clear',
          mini: true,
          onPressed: () => setState(() => _items.clear()),
          backgroundColor: const Color(0xFF21262D),
          child: const Icon(Icons.clear),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'start',
          onPressed: _startJob,
          backgroundColor: const Color(0xFF238636),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
        ),
      ],
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(
          children: [
            Icon(Icons.mic, size: 28),
            SizedBox(width: 12),
            Text('TTS Factory'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TTS Factory'),
            const SizedBox(height: 16),
            const Text(
              'Batch TTS client.\n\n'
              'Max 25 items\n'
              'Max 1100 chars/item\n'
              'Korean Neural2 voices',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Server: ${_serverUrl.isEmpty ? "Not configured" : _serverUrl}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Download: /Download/TTS-Factory/',
              style: TextStyle(color: Colors.grey, fontSize: 12),
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

class TTSItem {
  final String id;
  final String text;
  TTSItem({required this.id, required this.text});
}

enum JobStatus {
  idle('Ready'),
  queued('Queued...'),
  processing('Processing...'),
  downloading('Downloading...'),
  completed('Completed');

  final String label;
  const JobStatus(this.label);
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
