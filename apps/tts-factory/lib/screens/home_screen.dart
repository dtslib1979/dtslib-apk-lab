import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tts_item.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../widgets/selector_row.dart';
import '../widgets/stat_item.dart';
import '../widgets/tts_item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settings = SettingsService();
  bool _isLoading = true;

  final List<TTSItem> _items = [];
  String _preset = 'neutral';
  String _language = 'en';
  String? _currentJobId;
  JobStatus _jobStatus = JobStatus.idle;
  int _progress = 0;
  int _total = 0;
  Timer? _pollTimer;

  static const _presets = {
    'neutral': 'Neutral',
    'calm': 'Calm',
    'bright': 'Bright',
  };

  static const _languages = {
    'en': 'English',
    'ja': '日本語',
    'zh': '中文',
    'es': 'Español',
    'ko': '한국어',
  };

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    await _settings.init();
    setState(() {
      _preset = _settings.lastPreset;
      _language = _settings.lastLanguage;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFF85149),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF238636),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _parseAndAddContent(data.text!);
    } else {
      _showError('Clipboard is empty');
    }
  }

  void _parseAndAddContent(String content) {
    final newItems = TTSItem.parseFromText(content);
    if (newItems.isEmpty) {
      _showError('No valid text found');
      return;
    }

    // Re-index all items
    final allItems = [..._items, ...newItems];
    if (allItems.length > 25) {
      _showError('Max 25 items allowed (current: ${_items.length})');
      return;
    }

    for (int i = 0; i < allItems.length; i++) {
      allItems[i] = TTSItem(
        id: (i + 1).toString().padLeft(2, '0'),
        text: allItems[i].text,
      );
    }

    setState(() {
      _items.clear();
      _items.addAll(allItems);
    });
  }

  void _showAddTextDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Add Text'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter text (each line = one item)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _parseAndAddContent(text);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int index) {
    final item = _items[index];
    final controller = TextEditingController(text: item.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('Edit Item ${item.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                counterText: '${controller.text.length}/1100',
              ),
              onChanged: (_) => (ctx as Element).markNeedsBuild(),
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
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _items[index].text = text);
              }
              Navigator.pop(ctx);
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

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
      // Re-index
      for (int i = 0; i < _items.length; i++) {
        _items[i] = TTSItem(
          id: (i + 1).toString().padLeft(2, '0'),
          text: _items[i].text,
        );
      }
    });
  }

  Future<void> _startJob() async {
    final error = TTSItem.validate(_items);
    if (error != null) {
      _showError(error);
      return;
    }

    if (!_settings.isConfigured) {
      _showError('Server not configured - tap Settings');
      return;
    }

    setState(() => _jobStatus = JobStatus.queued);

    try {
      final service = TTSService(
        serverUrl: _settings.serverUrl,
        appSecret: _settings.appSecret,
      );

      _currentJobId = await service.createJob(
        items: _items,
        preset: _preset,
        language: _language,
      );

      setState(() {
        _jobStatus = JobStatus.processing;
        _total = _items.length;
      });
      _startPolling(service);
    } on TTSException catch (e) {
      _showError(e.message);
      setState(() => _jobStatus = JobStatus.idle);
    } catch (e) {
      _showError('Unexpected error: $e');
      setState(() => _jobStatus = JobStatus.idle);
    }
  }

  void _startPolling(TTSService service) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollStatus(service),
    );
  }

  Future<void> _pollStatus(TTSService service) async {
    if (_currentJobId == null) return;

    try {
      final status = await service.getJobStatus(_currentJobId!);

      if (!mounted) return;

      setState(() {
        _progress = status.progress;
        _total = status.total > 0 ? status.total : _items.length;
      });

      if (status.isCompleted) {
        _pollTimer?.cancel();
        await _downloadResult(service);
      } else if (status.isFailed) {
        _pollTimer?.cancel();
        _showError('Job failed: ${status.error ?? 'Unknown error'}');
        setState(() => _jobStatus = JobStatus.idle);
      }
    } on TTSException catch (e) {
      debugPrint('Poll error: ${e.message}');
    } catch (e) {
      debugPrint('Poll error: $e');
    }
  }

  Future<void> _downloadResult(TTSService service) async {
    if (_currentJobId == null) return;

    setState(() => _jobStatus = JobStatus.downloading);

    try {
      final path = await service.downloadResult(_currentJobId!);
      final fileName = path.split('/').last;
      _showSuccess('Downloaded: $fileName');

      setState(() {
        _jobStatus = JobStatus.idle;
        _currentJobId = null;
        _progress = 0;
        _items.clear();
      });
    } on TTSException catch (e) {
      _showError(e.message);
      setState(() => _jobStatus = JobStatus.idle);
    }
  }

  void _openSettings() {
    final urlController = TextEditingController(text: _settings.serverUrl);
    final secretController = TextEditingController(text: _settings.appSecret);

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
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Download: ${TTSService.downloadPath}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
              _settings.saveServerSettings(
                urlController.text,
                secretController.text,
              );
              Navigator.pop(ctx);
              _showSuccess('Settings saved');
              setState(() {});
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

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(
          children: [
            Icon(Icons.mic, size: 28),
            SizedBox(width: 12),
            Text('Parksy TTS'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('v1.1.0'),
            const SizedBox(height: 16),
            const Text(
              'Batch TTS client for Google Cloud TTS.\n\n'
              'Features:\n'
              '- Max 25 items per batch\n'
              '- Max 1100 chars per item\n'
              '- Multi-language Neural2 voices\n'
              '- 5 languages supported',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Server: ${_settings.isConfigured ? _settings.serverUrl : "Not configured"}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
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
            Text('Parksy TTS'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: _settings.isConfigured ? Colors.grey : Colors.orange,
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
            if (!_settings.isConfigured) _buildSetupBanner(),
            SelectorRow(
              label: 'Lang:',
              options: _languages,
              selected: _language,
              enabled: _jobStatus == JobStatus.idle,
              selectedColor: const Color(0xFF7EE787),
              onSelected: (lang) {
                setState(() => _language = lang);
                _settings.saveLanguage(lang);
              },
            ),
            SelectorRow(
              label: 'Voice:',
              options: _presets,
              selected: _preset,
              enabled: _jobStatus == JobStatus.idle,
              onSelected: (preset) {
                setState(() => _preset = preset);
                _settings.savePreset(preset);
              },
            ),
            const SizedBox(height: 16),
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
            StatItem(label: 'Items', value: '${_items.length}'),
            const StatItem(label: 'Max', value: '25'),
            StatItem(
              label: 'Chars',
              value: _items.isEmpty
                  ? '0'
                  : '${_items.map((e) => e.charCount).reduce((a, b) => a + b)}',
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
              'Paste or type text to start',
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
        return TTSItemCard(
          item: _items[index],
          index: index,
          enabled: _jobStatus == JobStatus.idle,
          onEdit: _jobStatus == JobStatus.idle
              ? () => _showEditDialog(index)
              : null,
          onDelete: _jobStatus == JobStatus.idle
              ? () => _deleteItem(index)
              : null,
        );
      },
    );
  }

  Widget? _buildFAB() {
    if (_jobStatus != JobStatus.idle) return null;

    if (_items.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            mini: true,
            onPressed: _showAddTextDialog,
            backgroundColor: const Color(0xFF21262D),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'paste',
            onPressed: _pasteFromClipboard,
            backgroundColor: const Color(0xFF238636),
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'add',
          mini: true,
          onPressed: _showAddTextDialog,
          backgroundColor: const Color(0xFF21262D),
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'clear',
          mini: true,
          onPressed: () => setState(() => _items.clear()),
          backgroundColor: const Color(0xFF21262D),
          child: const Icon(Icons.delete_outline),
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
}
