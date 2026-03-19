import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

// ── iOS 다크 팔레트 ──────────────────────────────────────────
const _kBg       = Color(0xFF000000);
const _kCard     = Color(0xFF1C1C1E);
const _kCardAlt  = Color(0xFF2C2C2E);
const _kText     = Color(0xFFFFFFFF);
const _kTextSec  = Color(0xFF8E8E93);
const _kSep      = Color(0xFF38383A);
const _kBlue     = Color(0xFF0A84FF);
const _kGreen    = Color(0xFF30D158);
const _kRed      = Color(0xFFFF453A);
const _kKeyBg    = Color(0xFF333333);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _tabIndex = 0;
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
    _call((_scholars.toList()..shuffle()).first);
  }

  void _showApiKeyDialog() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: _kCard,
        title: const Text('Gemini API 키',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('aistudio.google.com 에서 무료 발급',
                style: TextStyle(color: _kTextSec, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: _kText),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                hintStyle: TextStyle(color: _kTextSec.withOpacity(0.4)),
                filled: true, fillColor: _kCardAlt,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: _kTextSec))),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('gemini_api_key', ctrl.text.trim());
              setState(() => _apiKey = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('저장', style: TextStyle(color: _kBlue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
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

  // ── KEYPAD ──────────────────────────────────────────────────
  Widget _buildKeypad() {
    return Column(
      children: [
        const Spacer(flex: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _dialDisplay.isEmpty ? 'ChronoCall' : _dialDisplay,
            style: TextStyle(
              fontSize: _dialDisplay.isEmpty ? 22 : 34,
              fontWeight: _dialDisplay.isEmpty ? FontWeight.w300 : FontWeight.w400,
              color: _dialDisplay.isEmpty ? _kTextSec : _kText,
              letterSpacing: _dialDisplay.isEmpty ? 4 : 2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (_dialDisplay.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('학자 핫라인  ·  v3.7',
                style: TextStyle(color: _kTextSec.withOpacity(0.5), fontSize: 11)),
          ),
        const Spacer(flex: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(children: [
            _buildKeyRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
            const SizedBox(height: 14),
            _buildKeyRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
            const SizedBox(height: 14),
            _buildKeyRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
            const SizedBox(height: 14),
            _buildKeyRow(['*', '0', '#'], ['', '+', '']),
          ]),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 60),
            GestureDetector(
              onTap: _callRandom,
              child: Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _kGreen),
                child: const Icon(Icons.call, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(width: 12),
            if (_dialDisplay.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() =>
                    _dialDisplay = _dialDisplay.substring(0, _dialDisplay.length - 1)),
                child: SizedBox(width: 48, height: 48,
                    child: Icon(Icons.backspace_outlined, color: _kTextSec, size: 24)),
              )
            else const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _showApiKeyDialog,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.key, size: 14,
                color: _apiKey != null && _apiKey!.isNotEmpty ? _kGreen : _kTextSec),
            const SizedBox(width: 4),
            Text(_apiKey != null && _apiKey!.isNotEmpty ? 'API 키 설정됨' : 'API 키 설정',
                style: TextStyle(color: _kTextSec, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 4),
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
      onTap: () { setState(() => _dialDisplay += num); HapticFeedback.lightImpact(); },
      child: Container(
        width: 78, height: 78,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _kKeyBg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(num, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: _kText)),
            if (sub.isNotEmpty)
              Text(sub, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                  color: _kTextSec, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  // ── CONTACTS ────────────────────────────────────────────────
  Widget _buildContacts() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in _scholars) {
      final field = s['fieldKr'] ?? s['field'].toString().split(' / ').first;
      grouped.putIfAbsent(field, () => []).add(s);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(children: [
            const Text('연락처', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _kText)),
            const Spacer(),
            Text('${_scholars.length}명', style: TextStyle(color: _kTextSec, fontSize: 14)),
          ]),
        ),
        Expanded(
          child: ListView(
            children: grouped.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  color: _kBg,
                  child: Text(entry.key,
                      style: TextStyle(color: _kTextSec, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Container(
                  color: _kCard,
                  child: Column(
                    children: entry.value.asMap().entries.map((e) {
                      final s = e.value;
                      final isLast = e.key == entry.value.length - 1;
                      return Column(children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _kCardAlt,
                            child: Text(s['emoji'], style: const TextStyle(fontSize: 20)),
                          ),
                          title: Row(children: [
                            Text(s['nameKr'] ?? s['name'],
                                style: const TextStyle(fontSize: 16, color: _kText)),
                            const SizedBox(width: 6),
                            Text(s['name'],
                                style: TextStyle(fontSize: 11, color: _kTextSec)),
                          ]),
                          subtitle: Text(s['tagline'],
                              style: TextStyle(color: _kTextSec.withOpacity(0.6), fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: GestureDetector(
                            onTap: () => _call(s),
                            child: const Icon(Icons.call, color: _kGreen, size: 22),
                          ),
                          onTap: () => _call(s),
                        ),
                        if (!isLast) Divider(height: 1, indent: 72, color: _kSep),
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

  // ── RECENTS ─────────────────────────────────────────────────
  Widget _buildRecents() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: const Text('최근 통화', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _kText)),
        ),
        Expanded(
          child: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.call_made, size: 48, color: _kTextSec.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('통화 기록 없음', style: TextStyle(color: _kTextSec, fontSize: 15)),
              const SizedBox(height: 4),
              Text('통화 후 여기에 기록됩니다',
                  style: TextStyle(color: _kTextSec.withOpacity(0.4), fontSize: 12)),
            ],
          )),
        ),
      ],
    );
  }

  // ── TAB BAR ─────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: _kSep, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTab(0, Icons.dialpad, '키패드'),
          _buildTab(1, Icons.contacts, '연락처'),
          _buildTab(2, Icons.access_time, '최근'),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: active ? _kBlue : _kTextSec),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10,
              color: active ? _kBlue : _kTextSec)),
        ]),
      ),
    );
  }
}
