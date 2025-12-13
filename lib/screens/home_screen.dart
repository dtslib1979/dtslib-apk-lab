import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _recent = [];

  Future<void> _pickAudio() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    if (f.path == null) return;
    _addRecent(f.path!);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(path: f.path!),
      ),
    );
  }

  void _addRecent(String p) {
    setState(() {
      _recent.remove(p);
      _recent.insert(0, p);
      if (_recent.length > 10) _recent = _recent.sublist(0, 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIVA Prep')),
      body: Column(
        children: [
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.audio_file, size: 32),
              label: const Text('Pick Audio', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_recent.isNotEmpty) ...[
            const Text('Recent', style: TextStyle(fontSize: 16)),
            Expanded(
              child: ListView.builder(
                itemCount: _recent.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_recent[i].split('/').last),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditorScreen(path: _recent[i]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
