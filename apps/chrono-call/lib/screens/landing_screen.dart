import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _tabIndex = 0; // 0=Keypad, 1=Contacts, 2=Recents
  List<Map<String, dynamic>> _scholars = [];
  String? _apiKey;
  String _dialDisplay = '';

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

  void _call(Map<String, dynamic> scholar) {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _showApiKeyDialog();
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(scholar: scholar)));
  }

  void _callRandom() {
    if (_scholars.isEmpty) return;
    final scholar = (_scholars.toList()..shuffle()).first;
    _call(scholar);
  }

  void _showApiKeyDialog() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white,
        title: const Text('Gemini API Key',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Free from aistudio.google.com',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                filled: true, fillColor: const Color(0xFFF2F2F7),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400]))),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('gemini_api_key', ctrl.text.trim());
              setState(() => _apiKey = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Done',
                style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _tabIndex == 0 ? _buildKeypad() :
                     _tabIndex == 1 ? _buildContacts() :
                     _buildRecents(),
            ),
            _buildTabBar(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── KEYPAD (아이폰 전화 키패드) ─────────────────────────────
  // ═══════════════════════════════════════════════════════════
  Widget _buildKeypad() {
    return Column(
      children: [
        const Spacer(flex: 1),
        // 번호 표시
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _dialDisplay.isEmpty ? 'ChronoCall' : _dialDisplay,
            style: TextStyle(
              fontSize: _dialDisplay.isEmpty ? 22 : 32,
              fontWeight: _dialDisplay.isEmpty ? FontWeight.w300 : FontWeight.w400,
              color: _dialDisplay.isEmpty ? Colors.grey[400] : Colors.black,
              letterSpacing: _dialDisplay.isEmpty ? 4 : 2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (_dialDisplay.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('v3.6', style: TextStyle(color: Colors.grey[300], fontSize: 11)),
          ),
        const Spacer(flex: 1),
        // 키패드 그리드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              _buildKeyRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
              const SizedBox(height: 16),
              _buildKeyRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
              const SizedBox(height: 16),
              _buildKeyRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
              const SizedBox(height: 16),
              _buildKeyRow(['*', '0', '#'], ['', '+', '']),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 전화 버튼 + 백스페이스
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 60),
            GestureDetector(
              onTap: _callRandom,
              child: Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF34C759),
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(width: 12),
            if (_dialDisplay.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() =>
                    _dialDisplay = _dialDisplay.substring(0, _dialDisplay.length - 1)),
                child: const SizedBox(
                  width: 48, height: 48,
                  child: Icon(Icons.backspace_outlined, color: Colors.grey, size: 24),
                ),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 16),
        // 설정 버튼
        TextButton(
          onPressed: _showApiKeyDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.key, size: 14,
                  color: _apiKey != null && _apiKey!.isNotEmpty
                      ? const Color(0xFF34C759) : Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                _apiKey != null && _apiKey!.isNotEmpty ? 'API Key Set' : 'Set API Key',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildKeyRow(List<String> nums, List<String> subs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (i) => _buildKey(nums[i], subs[i])),
    );
  }

  Widget _buildKey(String num, String sub) {
    return GestureDetector(
      onTap: () {
        setState(() => _dialDisplay += num);
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 78, height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE5E5EA),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(num, style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w300, color: Colors.black)),
            if (sub.isNotEmpty)
              Text(sub, style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: Colors.grey[600], letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── CONTACTS (학자 전화번호부) ──────────────────────────────
  // ═══════════════════════════════════════════════════════════
  Widget _buildContacts() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in _scholars) {
      final field = s['field'].toString().split(' / ').first;
      grouped.putIfAbsent(field, () => []).add(s);
    }

    return Column(
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              const Text('Contacts',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_scholars.length}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            ],
          ),
        ),
        // 리스트
        Expanded(
          child: ListView(
            children: grouped.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 섹션 헤더
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  color: const Color(0xFFF2F2F7),
                  child: Text(entry.key.toUpperCase(),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12,
                          fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
                // 학자들
                Container(
                  color: Colors.white,
                  child: Column(
                    children: entry.value.asMap().entries.map((e) {
                      final s = e.value;
                      final isLast = e.key == entry.value.length - 1;
                      return Column(children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFF2F2F7),
                            child: Text(s['emoji'], style: const TextStyle(fontSize: 20)),
                          ),
                          title: Text(s['name'],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
                          subtitle: Text(s['tagline'],
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: GestureDetector(
                            onTap: () => _call(s),
                            child: const Icon(Icons.call, color: Color(0xFF34C759), size: 22),
                          ),
                          onTap: () => _call(s),
                        ),
                        if (!isLast) Divider(height: 1, indent: 72,
                            color: Colors.grey[200]),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            )).toList(),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── RECENTS (최근 통화) ────────────────────────────────────
  // ═══════════════════════════════════════════════════════════
  Widget _buildRecents() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              const Text('Recents',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_made, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No recent calls',
                    style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                const SizedBox(height: 4),
                Text('Your call history will appear here',
                    style: TextStyle(color: Colors.grey[300], fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── TAB BAR (아이폰 하단 탭) ──────────────────────────────
  // ═══════════════════════════════════════════════════════════
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTab(0, Icons.dialpad, 'Keypad'),
          _buildTab(1, Icons.contacts, 'Contacts'),
          _buildTab(2, Icons.access_time, 'Recents'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final active = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24,
                color: active ? const Color(0xFF007AFF) : Colors.grey[400]),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10,
                color: active ? const Color(0xFF007AFF) : Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}
