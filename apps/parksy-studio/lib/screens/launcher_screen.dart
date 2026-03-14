import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/studio_scenario.dart';
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
  int _tabIndex = 0;
  StudioScenario? _selected;
  String _toolCategory = 'all';

  final List<Map<String, String>> _toolCategories = [
    {'id': 'all', 'label': '전체'},
    {'id': 'video', 'label': '영상'},
    {'id': 'audio', 'label': '오디오'},
    {'id': 'image', 'label': '이미지'},
    {'id': 'util', 'label': '유틸'},
  ];

  List<StudioTool> get _filteredTools => _toolCategory == 'all'
      ? kTools
      : kTools.where((t) => t.category == _toolCategory).toList();

  void _selectScenario(StudioScenario s) {
    setState(() => _selected = s);
    if (s.isCustom) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => const RecordingScreen(),
      ));
    } else if (s.autoOpenTool == 'bgm') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BgmScreen()));
    } else if (s.autoOpenTool == 'interpreter') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InterpreterScreen()));
    }
  }

  void _startRecording() {
    final s = _selected;
    if (s == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RecordingScreen(scenario: s),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _tabIndex == 0 ? _buildScenarioTab() : _buildToolTab()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── 헤더 ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text('PARKSY STUDIO',
              style: TextStyle(color: AppConstants.kAccent, fontSize: 18,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
          const Spacer(),
          Text('v${AppConstants.version}',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  // ── 시나리오 탭 ───────────────────────────────────────────────────
  Widget _buildScenarioTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            Text('방송 시나리오',
                style: TextStyle(color: AppConstants.kAccent, fontSize: 12, letterSpacing: 1)),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
            ),
            itemCount: kScenarios.length,
            itemBuilder: (_, i) => _buildScenarioCard(kScenarios[i]),
          ),
        ),
        if (_selected != null && !_selected!.isCustom) _buildSelectedPanel(),
      ],
    );
  }

  Widget _buildScenarioCard(StudioScenario s) {
    final sel = _selected?.id == s.id;
    return GestureDetector(
      onTap: () => _selectScenario(s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? AppConstants.kAccent.withOpacity(0.15) : AppConstants.kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? AppConstants.kAccent : AppConstants.kDim,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(s.icon, style: const TextStyle(fontSize: 26)),
            const Spacer(),
            if (sel)
              Icon(Icons.check_circle, color: AppConstants.kAccent, size: 16),
          ]),
          const SizedBox(height: 8),
          Text(s.name,
              style: TextStyle(
                  color: sel ? AppConstants.kAccent : Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(s.desc,
              style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _buildSelectedPanel() {
    final s = _selected!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.kAccent.withOpacity(0.4)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _infoChip('포맷', s.formatLabel)),
          const SizedBox(width: 8),
          Expanded(child: _infoChip('마이크', s.audioSourceLabel)),
          const SizedBox(width: 8),
          Expanded(child: _infoChip('이펙트', s.effectsLabel)),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _startRecording,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: AppConstants.kAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('⏺  ${s.name}  녹화 시작',
                  style: const TextStyle(color: Colors.black,
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(color: AppConstants.kAccent, fontSize: 11, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis),
    ]);
  }

  // ── 도구 탭 ───────────────────────────────────────────────────────
  Widget _buildToolTab() {
    return Column(children: [
      SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _toolCategories.length,
          itemBuilder: (_, i) {
            final cat = _toolCategories[i];
            final sel = _toolCategory == cat['id'];
            return GestureDetector(
              onTap: () => setState(() => _toolCategory = cat['id']!),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppConstants.kAccent : AppConstants.kSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(cat['label']!,
                    style: TextStyle(
                        color: sel ? Colors.black : Colors.white60,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _filteredTools.length,
          itemBuilder: (_, i) => _buildToolCard(_filteredTools[i]),
        ),
      ),
    ]);
  }

  Widget _buildToolCard(StudioTool tool) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => StudioWebView(
            url: AppConstants.cloudAppstoreBase + tool.url,
            title: tool.name,
          ),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppConstants.kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.kDim),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(tool.icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(tool.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ]),
      ),
    );
  }

  // ── 하단 탭바 ─────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      height: 56,
      color: AppConstants.kSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _tab(0, '🎬', '시나리오'),
          _tab(1, '🧰', '도구'),
          _navBtn('🎵', 'BGM',  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BgmScreen()))),
          _navBtn('🌐', '통역', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterpreterScreen()))),
          _navBtn('☁️', '업로드', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen()))),
        ],
      ),
    );
  }

  Widget _tab(int idx, String icon, String label) {
    final sel = _tabIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        Text(label,
            style: TextStyle(
                color: sel ? AppConstants.kAccent : Colors.white38,
                fontSize: 10,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }

  Widget _navBtn(String icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ]),
    );
  }
}
