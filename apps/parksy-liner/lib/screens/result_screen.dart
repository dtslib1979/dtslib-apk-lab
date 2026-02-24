import 'dart:io';
import 'package:flutter/material.dart';
import '../services/notes_bridge.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, String> outputPaths;
  final String sourcePath;

  const ResultScreen({
    super.key,
    required this.outputPaths,
    required this.sourcePath,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String _currentView = 'combo';
  bool _hasNotes = false;

  @override
  void initState() {
    super.initState();
    _checkNotes();
  }

  Future<void> _checkNotes() async {
    final available = await NotesBridge.isSamsungNotesAvailable();
    if (mounted) setState(() => _hasNotes = available);
  }

  String? get _currentPath => widget.outputPaths[_currentView];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Result'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: const Color(0xFFE8D5B7),
        elevation: 0,
        actions: [
          if (_hasNotes)
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Open in Samsung Notes',
              onPressed: () => _openInNotes(),
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => _share(),
          ),
        ],
      ),
      body: Column(
        children: [
          // View selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _viewTab('combo', 'Combo'),
                _viewTab('line', 'Line'),
                _viewTab('shade', 'Shade'),
                _viewTab('preview', 'Debug'),
              ],
            ),
          ),

          // Image display
          Expanded(
            child: _currentPath != null && File(_currentPath!).existsSync()
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(
                      child: Image.file(
                        File(_currentPath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                : const Center(
                    child: Text(
                      'File not found',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _hasNotes ? _openInNotes : _share,
                    icon: Icon(_hasNotes ? Icons.edit_note : Icons.share),
                    label: Text(
                      _hasNotes ? 'Open in Samsung Notes' : 'Share',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8D5B7),
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewTab(String key, String label) {
    final active = _currentView == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentView = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE8D5B7).withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(0xFFE8D5B7).withOpacity(0.4)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? const Color(0xFFE8D5B7) : Colors.white54,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInNotes() async {
    final comboPath = widget.outputPaths['combo'];
    if (comboPath == null) return;
    await NotesBridge.openInSamsungNotes(comboPath);
  }

  Future<void> _share() async {
    final path = _currentPath;
    if (path == null) return;
    await NotesBridge.shareImage(path);
  }
}
