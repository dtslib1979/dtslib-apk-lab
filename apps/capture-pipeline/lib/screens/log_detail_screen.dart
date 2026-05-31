import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_config.dart';

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
    await platform.invokeMethod('speakText', {'text': body});
    setState(() => _isPlaying = true);
    final estimatedSec = (body.length / 4).round() + 10;
    Future.delayed(Duration(seconds: estimatedSec), () {
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
