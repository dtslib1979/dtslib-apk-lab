import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

// ── 아이폰 + 파피루스 팔레트 ──────────────────────────────────
const _kPapyrus    = Color(0xFFF5ECD7);  // 파피루스 배경
const _kPapyrusDk  = Color(0xFFE8DCC8);  // 파피루스 진한
const _kInk        = Color(0xFF2C1810);  // 잉크 텍스트
const _kInkLight   = Color(0xFF8B7355);  // 연한 잉크
const _kIosBlue    = Color(0xFF007AFF);  // iOS 블루
const _kIosGreen   = Color(0xFF34C759);  // iOS 그린
const _kIosGrey    = Color(0xFFF2F2F7);  // iOS 그레이 배경
const _kSeparator  = Color(0xFFD4C5A9);  // 구분선

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  List<Map<String, dynamic>> _scholars = [];
  String? _apiKey;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPhonebook();
    _loadApiKey();
  }

  Future<void> _loadPhonebook() async {
    final json = await rootBundle.loadString('assets/phonebook.json');
    final list = jsonDecode(json) as List;
    setState(() => _scholars = list.cast<Map<String, dynamic>>());
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _apiKey = prefs.getString('gemini_api_key'));
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _scholars;
    final q = _searchQuery.toLowerCase();
    return _scholars.where((s) =>
        s['name'].toString().toLowerCase().contains(q) ||
        s['field'].toString().toLowerCase().contains(q)).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in _filtered) {
      final field = s['field'].toString().split(' / ').first;
      map.putIfAbsent(field, () => []).add(s);
    }
    return map;
  }

  void _call(Map<String, dynamic> scholar) {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _showApiKeyDialog();
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(scholar: scholar),
    ));
  }

  void _showApiKeyDialog() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Gemini API Key',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Free from aistudio.google.com',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                filled: true, fillColor: _kIosGrey,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('gemini_api_key', ctrl.text.trim());
              setState(() => _apiKey = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: _kIosBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPapyrus,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildPhonebook()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHRONOCALL',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  )),
              const SizedBox(height: 2),
              Text('Scholar Hotline  ·  v3.5',
                  style: TextStyle(color: _kInkLight, fontSize: 12,
                      letterSpacing: 1.5)),
            ],
          )),
          GestureDetector(
            onTap: _showApiKeyDialog,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPapyrusDk,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.key,
                  color: _apiKey != null && _apiKey!.isNotEmpty
                      ? _kIosGreen : _kInkLight, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(color: _kInk, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search scholars...',
          hintStyle: TextStyle(color: _kInkLight.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: _kInkLight, size: 20),
          filled: true,
          fillColor: _kPapyrusDk.withOpacity(0.6),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildPhonebook() {
    final groups = _grouped;
    if (groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      children: groups.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Text(entry.key.toUpperCase(),
                  style: TextStyle(color: _kInkLight, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
            // 학자 카드들
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kSeparator.withOpacity(0.5)),
              ),
              child: Column(
                children: entry.value.asMap().entries.map((e) {
                  final scholar = e.value;
                  final isLast = e.key == entry.value.length - 1;
                  return Column(children: [
                    _buildScholarTile(scholar),
                    if (!isLast) Divider(height: 1, indent: 72,
                        color: _kSeparator.withOpacity(0.4)),
                  ]);
                }).toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildScholarTile(Map<String, dynamic> scholar) {
    return InkWell(
      onTap: () => _call(scholar),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 프로필 아이콘
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _kPapyrusDk,
                borderRadius: BorderRadius.circular(23),
              ),
              child: Center(child: Text(scholar['emoji'],
                  style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            // 이름 + 분야 + 명언
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(scholar['name'],
                      style: TextStyle(color: _kInk, fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text(scholar['years'],
                      style: TextStyle(color: _kInkLight.withOpacity(0.6),
                          fontSize: 10)),
                ]),
                const SizedBox(height: 2),
                Text(scholar['tagline'],
                    style: TextStyle(color: _kInkLight, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
            // 전화 버튼
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kIosGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.call, color: _kIosGreen, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _kSeparator.withOpacity(0.4))),
      ),
      child: Column(children: [
        Text('${_scholars.length} scholars · All public domain (70yr+)',
            style: TextStyle(color: _kInkLight.withOpacity(0.5), fontSize: 10)),
        const SizedBox(height: 2),
        Text('Powered by Gemini · No screen needed',
            style: TextStyle(color: _kInkLight.withOpacity(0.3), fontSize: 9)),
      ]),
    );
  }
}
