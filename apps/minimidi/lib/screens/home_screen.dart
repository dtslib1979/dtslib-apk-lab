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
      appBar: AppBar(
        title: const Text('MiniMidi'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 48),
          Center(
            child: ElevatedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.audio_file, size: 32),
              label: const Text(
                'Pick Audio',
                style: TextStyle(fontSize: 20),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_recent.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _recent.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(
                    _recent[i].split('/').last,
                    overflow: TextOverflow.ellipsis,
                  ),
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
