import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import 'studio_webview.dart';
import 'recording_screen.dart';
import 'interpreter_screen.dart';
import 'bgm_screen.dart';
import 'upload_screen.dart';

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': '전체'},
    {'id': 'video', 'label': '영상'},
    {'id': 'audio', 'label': '오디오'},
    {'id': 'image', 'label': '이미지'},
    {'id': 'util', 'label': '유틸'},
    {'id': 'game', 'label': '게임'},
  ];

  List<StudioTool> get _filteredTools => _selectedCategory == 'all'
      ? kTools
      : kTools.where((t) => t.category == _selectedCategory).toList();

  void _openTool(StudioTool tool) {
    final url = AppConstants.cloudAppstoreBase + tool.url;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudioWebView(
          url: url,
          title: tool.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryBar(),
            Expanded(child: _buildToolGrid()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            'PARKSY STUDIO',
            style: TextStyle(
              color: AppConstants.kAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Text(
            'v${AppConstants.version}',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat['id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['id']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppConstants.kAccent : AppConstants.kSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                cat['label']!,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white60,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolGrid() {
    final tools = _filteredTools;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: tools.length,
      itemBuilder: (_, i) => _buildToolCard(tools[i]),
    );
  }

  Widget _buildToolCard(StudioTool tool) {
    return GestureDetector(
      onTap: () => _openTool(tool),
      child: Container(
        decoration: BoxDecoration(
          color: AppConstants.kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.kDim, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tool.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                tool.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 56,
      color: AppConstants.kSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomBtn('🏠', '런처', () {}),
          _bottomBtn('🎬', '녹화', () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RecordingScreen()))),
          _bottomBtn('🌐', '통역', () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InterpreterScreen()))),
          _bottomBtn('🎵', 'BGM', () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BgmScreen()))),
          _bottomBtn('☁️', '업로드', () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const UploadScreen()))),
        ],
      ),
    );
  }

  Widget _bottomBtn(String icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

}
