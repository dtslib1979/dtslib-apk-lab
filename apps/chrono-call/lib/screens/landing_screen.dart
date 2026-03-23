import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, HapticFeedback, rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

// ── 프리미엄 다크 팔레트 ─────────────────────────────────────
const _kBg       = Color(0xFF08080D);
const _kSurface  = Color(0xFF12121A);
const _kCard     = Color(0xFF161622);
const _kCardHi   = Color(0xFF1E1E30);
const _kGlass    = Color(0x18FFFFFF);
const _kText     = Color(0xFFF2F2F7);
const _kTextSec  = Color(0xFF8E8EA0);
const _kTextDim  = Color(0xFF505068);
const _kBorder   = Color(0xFF28283E);
const _kAccent   = Color(0xFF64FFDA);
const _kBlue     = Color(0xFF5E7CFF);
const _kGreen    = Color(0xFF30D158);
const _kRed      = Color(0xFFFF453A);
const _kGold     = Color(0xFFFFD700);
const _kCyan     = Color(0xFF64FFDA);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  int _tabIndex = 1;
  Widget? _activeCallWidget;
  List<Map<String, dynamic>> _scholars = [];
  List<Map<String, String>> _apiKeys = [];
  int _activeKeyIndex = 0;
  String? get _apiKey => _apiKeys.isNotEmpty ? _apiKeys[_activeKeyIndex]['key'] : null;
  String get _apiStatus => _apiKeys.isNotEmpty ? (_apiKeys[_activeKeyIndex]['status'] ?? '') : '';
  String _dialDisplay = '';

  bool _conferenceMode = false;
  final _selectedScholars = <Map<String, dynamic>>{};

  late final AnimationController _glowCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _tabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _loadPhonebook();
    _loadApiKey();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _pulseCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhonebook() async {
    final json = await rootBundle.loadString('assets/phonebook.json');
    final list = jsonDecode(json) as List;
    setState(() => _scholars = list.cast<Map<String, dynamic>>());
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final keysJson = prefs.getString('claude_api_keys');
    if (keysJson != null) {
      final list = jsonDecode(keysJson) as List;
      setState(() => _apiKeys = list.map((e) => Map<String, String>.from(e)).toList());
    } else {
      final old = prefs.getString('claude_api_key');
      if (old != null && old.isNotEmpty) {
        setState(() => _apiKeys = [{'name': 'Default', 'key': old, 'status': ''}]);
        _saveKeys();
      }
    }
    _activeKeyIndex = prefs.getInt('claude_active_key') ?? 0;
    if (_activeKeyIndex >= _apiKeys.length) _activeKeyIndex = 0;
    for (int i = 0; i < _apiKeys.length; i++) {
      _verifyKey(i);
    }
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('claude_api_keys', jsonEncode(_apiKeys));
    await prefs.setInt('claude_active_key', _activeKeyIndex);
  }

  Future<void> _verifyKey(int index) async {
    if (index >= _apiKeys.length) return;
    setState(() => _apiKeys[index]['status'] = 'checking');
    try {
      final res = await http.get(
        Uri.parse('https://api.anthropic.com/v1/models'),
        headers: {
          'x-api-key': _apiKeys[index]['key']!,
          'anthropic-version': '2023-06-01',
        },
      ).timeout(const Duration(seconds: 10));
      setState(() => _apiKeys[index]['status'] = res.statusCode == 200 ? 'valid' : 'error:${res.statusCode}');
    } catch (_) {
      setState(() => _apiKeys[index]['status'] = 'error:network');
    }
  }

  void _call(Map<String, dynamic> scholar) {
    if (_apiKey == null || _apiKey!.isEmpty) { _showApiKeyDialog(); return; }
    setState(() {
      _activeCallWidget = ChatScreen(scholar: scholar);
      _tabIndex = 2;
    });
  }

  void _startConference() {
    if (_selectedScholars.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('2명 이상 선택하세요')));
      return;
    }
    if (_apiKey == null || _apiKey!.isEmpty) { _showApiKeyDialog(); return; }
    setState(() {
      _activeCallWidget = ChatScreen(
        scholar: _selectedScholars.first,
        conferenceScholars: _selectedScholars.toList(),
      );
      _tabIndex = 2;
    });
  }

  void _callRandom() {
    if (_scholars.isEmpty) return;
    _call((_scholars.toList()..shuffle()).first);
  }

  void _showApiKeyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApiKeySheet(
        apiKeys: _apiKeys,
        activeKeyIndex: _activeKeyIndex,
        onKeysChanged: (keys, activeIdx) {
          setState(() {
            _apiKeys = keys;
            _activeKeyIndex = activeIdx;
          });
          _saveKeys();
        },
        onVerify: _verifyKey,
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _tabIndex == 0 ? _buildKeypad() :
                       _tabIndex == 1 ? _buildContacts() :
                       _tabIndex == 2 ? _buildCallTab() :
                       _buildRecents(),
              ),
            ),
            if (_conferenceMode && _selectedScholars.isNotEmpty)
              _buildConferenceBar(),
            _buildTabBar(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── KEYPAD ─────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════
  Widget _buildKeypad() {
    return Container(
      key: const ValueKey('keypad'),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // 로고 + 글로우
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: const [_kCyan, _kBlue, Color(0xFFBB86FC)],
                stops: [0, _glowCtrl.value, 1],
              ).createShader(bounds),
              child: Text(
                _dialDisplay.isEmpty ? 'CHRONO' : _dialDisplay,
                style: TextStyle(
                  fontSize: _dialDisplay.isEmpty ? 36 : 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: _dialDisplay.isEmpty ? 12 : 4,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (_dialDisplay.isEmpty) ...[
            const SizedBox(height: 2),
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => Opacity(
                opacity: 0.3 + _glowCtrl.value * 0.3,
                child: const Text('CALL',
                    style: TextStyle(color: _kCyan, fontSize: 14,
                        letterSpacing: 20, fontWeight: FontWeight.w300)),
              ),
            ),
            const SizedBox(height: 8),
            Text('SCHOLAR HOTLINE',
                style: TextStyle(color: _kTextDim.withOpacity(0.6), fontSize: 9,
                    letterSpacing: 6, fontWeight: FontWeight.w500)),
          ],
          const Spacer(flex: 1),
          // 키패드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
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
          const SizedBox(height: 32),
          // 전화 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 60),
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kGreen.withOpacity(0.15 + _pulseCtrl.value * 0.15),
                        blurRadius: 24 + _pulseCtrl.value * 12,
                        spreadRadius: _pulseCtrl.value * 4,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: GestureDetector(
                  onTap: _callRandom,
                  child: Container(
                    width: 68, height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF30D158), Color(0xFF25A84A)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: const Icon(Icons.call, color: Colors.white, size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_dialDisplay.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() =>
                      _dialDisplay = _dialDisplay.substring(0, _dialDisplay.length - 1)),
                  child: SizedBox(width: 48, height: 48,
                      child: Icon(Icons.backspace_outlined, color: _kTextSec, size: 20)),
                )
              else const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          // API 키 상태
          GestureDetector(
            onTap: _showApiKeyDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _kGlass,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _apiStatus == 'valid' ? _kGreen :
                           _apiStatus == 'checking' ? _kGold :
                           _apiStatus.startsWith('error') ? _kRed : _kTextDim,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _apiStatus == 'valid' ? 'Connected' :
                  _apiStatus == 'checking' ? 'Verifying...' :
                  _apiStatus.startsWith('error') ? 'Error' :
                  _apiKey != null && _apiKey!.isNotEmpty ? 'Unverified' : 'Set API Key',
                  style: TextStyle(color: _kTextSec, fontSize: 11,
                      fontWeight: FontWeight.w500, letterSpacing: 0.5),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
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
        width: 74, height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kSurface,
          border: Border.all(color: _kBorder.withOpacity(0.5), width: 0.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(num, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300, color: _kText)),
            if (sub.isNotEmpty)
              Text(sub, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                  color: _kTextDim, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── CONTACTS ───────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════
  Widget _buildContacts() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in _scholars) {
      final field = s['fieldKr'] ?? s['field'].toString().split(' / ').first;
      grouped.putIfAbsent(field, () => []).add(s);
    }

    return Container(
      key: const ValueKey('contacts'),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('연락처',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                          color: _kText, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('${_scholars.length} scholars',
                      style: TextStyle(color: _kTextDim, fontSize: 12,
                          fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                ],
              ),
              const Spacer(),
              // 컨퍼런스 모드 토글
              GestureDetector(
                onTap: () => setState(() {
                  _conferenceMode = !_conferenceMode;
                  if (!_conferenceMode) _selectedScholars.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _conferenceMode ? _kGold.withOpacity(0.12) : _kSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: _conferenceMode ? _kGold.withOpacity(0.4) : _kBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_conferenceMode ? Icons.groups : Icons.person,
                        size: 14,
                        color: _conferenceMode ? _kGold : _kTextSec),
                    const SizedBox(width: 6),
                    Text(_conferenceMode ? 'Conference' : '1 : 1',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _conferenceMode ? _kGold : _kTextSec,
                            letterSpacing: 0.5)),
                  ]),
                ),
              ),
            ]),
          ),
          if (_conferenceMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
              child: Text('Select 2-4 scholars for conference',
                  style: TextStyle(color: _kTextDim, fontSize: 11, letterSpacing: 0.3)),
            ),
          const SizedBox(height: 8),
          // 리스트
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: grouped.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 섹션 헤더
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 24, 8),
                    child: Text(entry.key.toUpperCase(),
                        style: TextStyle(color: _kAccent.withOpacity(0.6), fontSize: 11,
                            fontWeight: FontWeight.w700, letterSpacing: 2)),
                  ),
                  // 학자 카드
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kBorder.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2),
                            blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: entry.value.asMap().entries.map((e) {
                          final s = e.value;
                          final isLast = e.key == entry.value.length - 1;
                          final isSelected = _selectedScholars.contains(s);
                          return Column(children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (_conferenceMode) {
                                    setState(() {
                                      if (isSelected) { _selectedScholars.remove(s); }
                                      else if (_selectedScholars.length < 4) { _selectedScholars.add(s); }
                                    });
                                  } else { _call(s); }
                                },
                                splashColor: _kAccent.withOpacity(0.05),
                                highlightColor: _kAccent.withOpacity(0.03),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _kGold.withOpacity(0.06) : Colors.transparent,
                                  ),
                                  child: Row(children: [
                                    // 프로필 아바타
                                    Container(
                                      width: 46, height: 46,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        gradient: isSelected
                                            ? const LinearGradient(
                                                colors: [_kGold, Color(0xFFFFA000)],
                                                begin: Alignment.topLeft, end: Alignment.bottomRight)
                                            : LinearGradient(
                                                colors: [_kCardHi, _kCard],
                                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                                        border: isSelected
                                            ? Border.all(color: _kGold.withOpacity(0.6), width: 1.5)
                                            : Border.all(color: _kBorder.withOpacity(0.3), width: 0.5),
                                        boxShadow: isSelected ? [
                                          BoxShadow(color: _kGold.withOpacity(0.2), blurRadius: 8),
                                        ] : null,
                                      ),
                                      child: Center(child: Text(s['emoji'],
                                          style: const TextStyle(fontSize: 22))),
                                    ),
                                    const SizedBox(width: 14),
                                    // 이름
                                    Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s['nameKr'] ?? s['name'],
                                            style: const TextStyle(fontSize: 15, color: _kText,
                                                fontWeight: FontWeight.w600, letterSpacing: -0.2),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text(s['name'],
                                            style: TextStyle(fontSize: 11, color: _kTextDim,
                                                letterSpacing: 0.3),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 1),
                                        Text(s['tagline'],
                                            style: TextStyle(color: _kTextSec, fontSize: 11),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    )),
                                    const SizedBox(width: 8),
                                    // 전화/체크
                                    if (_conferenceMode)
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 24, height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? _kGold : Colors.transparent,
                                          border: Border.all(
                                              color: isSelected ? _kGold : _kTextDim.withOpacity(0.5),
                                              width: 1.5),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, color: Colors.black, size: 14)
                                            : null,
                                      )
                                    else
                                      Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: _kGreen.withOpacity(0.08),
                                          border: Border.all(color: _kGreen.withOpacity(0.15)),
                                        ),
                                        child: const Icon(Icons.call, color: _kGreen, size: 16),
                                      ),
                                  ]),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Padding(
                                padding: const EdgeInsets.only(left: 76),
                                child: Container(height: 0.5, color: _kBorder.withOpacity(0.3)),
                              ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 컨퍼런스 바 ─────────────────────────────────────────────
  Widget _buildConferenceBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kGold.withOpacity(0.15))),
        boxShadow: [BoxShadow(color: _kGold.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        ...(_selectedScholars.map((s) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                  colors: [_kGold, Color(0xFFFFA000)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: _kGold.withOpacity(0.2), blurRadius: 8)],
            ),
            child: Center(child: Text(s['emoji'], style: const TextStyle(fontSize: 17))),
          ),
        ))),
        const Spacer(),
        Text('${_selectedScholars.length}/4',
            style: TextStyle(color: _kGold.withOpacity(0.7), fontSize: 12,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: _startConference,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kGold, Color(0xFFFFA000)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: _kGold.withOpacity(0.3), blurRadius: 16)],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.groups, color: Colors.black, size: 16),
              SizedBox(width: 6),
              Text('START', style: TextStyle(color: Colors.black,
                  fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── 통화 탭 ─────────────────────────────────────────────────
  Widget _buildCallTab() {
    if (_activeCallWidget != null) return _activeCallWidget!;
    return Container(
      key: const ValueKey('call-empty'),
      child: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kSurface,
              border: Border.all(color: _kBorder),
            ),
            child: Icon(Icons.call, size: 36, color: _kTextDim.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          const Text('No Active Call', style: TextStyle(color: _kTextSec, fontSize: 16,
              fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text('Select a scholar from Contacts',
              style: TextStyle(color: _kTextDim, fontSize: 12, letterSpacing: 0.3)),
        ],
      )),
    );
  }

  // ── 녹취록 ──────────────────────────────────────────────────
  List<FileSystemEntity> _recordings = [];
  List<Map<String, dynamic>> _groupedRecordings = [];

  Future<void> _loadRecordings() async {
    final dir = Directory('/sdcard/Download/ChronoCall');
    if (!await dir.exists()) return;
    final files = dir.listSync()..sort((a, b) => b.path.compareTo(a.path));
    setState(() => _recordings = files);

    final groups = <String, Map<String, dynamic>>{};
    for (final f in files) {
      final name = f.path.split('/').last;
      final base = name.replaceAll('.md', '').replaceAll('.m4a', '').replaceAll('.mp3', '');
      groups.putIfAbsent(base, () => {'name': base, 'date': f.statSync().modified});
      if (name.endsWith('.md')) groups[base]!['md'] = f.path;
      if (name.endsWith('.m4a') || name.endsWith('.mp3')) groups[base]!['audio'] = f.path;
    }
    setState(() => _groupedRecordings = groups.values.toList());
  }

  Widget _buildRecents() {
    if (_recordings.isEmpty) _loadRecordings();
    return Container(
      key: const ValueKey('recents'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('녹취록',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                          color: _kText, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('${_groupedRecordings.length} recordings',
                      style: TextStyle(color: _kTextDim, fontSize: 12,
                          fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () { _recordings.clear(); _loadRecordings(); },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.refresh, color: _kTextSec, size: 18),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _groupedRecordings.isEmpty
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kSurface,
                          border: Border.all(color: _kBorder),
                        ),
                        child: Icon(Icons.description_outlined, size: 36,
                            color: _kTextDim.withOpacity(0.4)),
                      ),
                      const SizedBox(height: 20),
                      const Text('No Recordings', style: TextStyle(color: _kTextSec,
                          fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Auto-saved after each call',
                          style: TextStyle(color: _kTextDim, fontSize: 12)),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _groupedRecordings.length,
                    itemBuilder: (_, i) {
                      final group = _groupedRecordings[i];
                      final mdPath = group['md'];
                      final audioPath = group['audio'];
                      final name = group['name'] ?? 'unknown';
                      final date = group['date'] as DateTime;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _kBorder.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.15),
                                blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: _kAccent.withOpacity(0.08),
                                  border: Border.all(color: _kAccent.withOpacity(0.15)),
                                ),
                                child: const Icon(Icons.mic, color: _kAccent, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(color: _kText, fontSize: 14,
                                          fontWeight: FontWeight.w600, letterSpacing: -0.2),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text('${date.month}/${date.day}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(color: _kTextDim, fontSize: 11)),
                                ],
                              )),
                            ]),
                            const SizedBox(height: 14),
                            Row(children: [
                              if (mdPath != null)
                                Expanded(child: GestureDetector(
                                  onTap: () => _showTranscript(mdPath),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _kAccent.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _kAccent.withOpacity(0.12)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.description_outlined, color: _kAccent.withOpacity(0.8), size: 15),
                                        const SizedBox(width: 6),
                                        Text('Transcript', style: TextStyle(
                                            color: _kAccent.withOpacity(0.9), fontSize: 12,
                                            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                                      ],
                                    ),
                                  ),
                                )),
                              if (mdPath != null && audioPath != null)
                                const SizedBox(width: 10),
                              if (audioPath != null)
                                Expanded(child: GestureDetector(
                                  onTap: () => _playRecording(audioPath),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _kBlue.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _kBlue.withOpacity(0.12)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_arrow, color: _kBlue.withOpacity(0.8), size: 16),
                                        const SizedBox(width: 6),
                                        Text('Play', style: TextStyle(
                                            color: _kBlue.withOpacity(0.9), fontSize: 12,
                                            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                                      ],
                                    ),
                                  ),
                                )),
                              if (mdPath == null && audioPath == null)
                                Text('No files', style: TextStyle(color: _kTextDim)),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static const _voiceCh = MethodChannel('com.parksy.chronocall/voice');

  void _playRecording(String path) async {
    try {
      await _voiceCh.invokeMethod('playFile', {'path': path});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing: ${path.split('/').last}'),
          backgroundColor: _kGreen.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (_) {}
  }

  void _showTranscript(String path) async {
    try {
      final content = await File(path).readAsString();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 핸들
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _kAccent.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.description_outlined, color: _kAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(path.split('/').last,
                      style: const TextStyle(color: _kText, fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const SizedBox(height: 16),
              Container(height: 0.5, color: _kBorder.withOpacity(0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 20)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(content, style: TextStyle(color: _kText.withOpacity(0.85),
                      fontSize: 13, height: 1.7, letterSpacing: 0.2)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  // ── TAB BAR ─────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder.withOpacity(0.3), width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTab(0, Icons.dialpad, '키패드'),
          _buildTab(1, Icons.contacts_outlined, '연락처'),
          _buildTab(2, Icons.call, '통화'),
          _buildTab(3, Icons.description_outlined, '녹취록'),
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
        width: 72,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48, height: 28,
            decoration: BoxDecoration(
              color: active ? _kAccent.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20,
                color: active ? _kAccent : _kTextDim),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10,
              color: active ? _kAccent : _kTextDim,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.2)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ── API KEY SHEET ────────────────────────────────────────
// ═══════════════════════════════════════════════════════════
class _ApiKeySheet extends StatefulWidget {
  final List<Map<String, String>> apiKeys;
  final int activeKeyIndex;
  final void Function(List<Map<String, String>>, int) onKeysChanged;
  final void Function(int) onVerify;

  const _ApiKeySheet({required this.apiKeys, required this.activeKeyIndex,
      required this.onKeysChanged, required this.onVerify});
  @override
  State<_ApiKeySheet> createState() => _ApiKeySheetState();
}

class _ApiKeySheetState extends State<_ApiKeySheet> {
  late List<Map<String, String>> _keys;
  late int _activeIdx;
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _keys = List.from(widget.apiKeys);
    _activeIdx = widget.activeKeyIndex;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _kBorder,
              borderRadius: BorderRadius.circular(2)),
          )),
          Row(children: [
            const Text('API Keys',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kText)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_keys.length}/3', style: TextStyle(color: _kTextSec, fontSize: 12,
                  fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Auto-switch on 429 rate limit',
              style: TextStyle(color: _kTextDim, fontSize: 11, letterSpacing: 0.3)),
          const SizedBox(height: 20),
          // 키 목록
          ...(_keys.asMap().entries.map((e) {
            final i = e.key;
            final k = e.value;
            final isActive = i == _activeIdx;
            final status = k['status'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? _kAccent.withOpacity(0.05) : _kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isActive ? _kAccent.withOpacity(0.3) : _kBorder.withOpacity(0.5)),
              ),
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status == 'valid' ? _kGreen :
                           status == 'checking' ? _kGold :
                           status.startsWith('error') ? _kRed : _kTextDim,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k['name'] ?? 'Key ${i + 1}',
                        style: TextStyle(color: _kText, fontSize: 13,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
                    const SizedBox(height: 2),
                    Text('...${k['key']?.substring((k['key']?.length ?? 4) - 4)}',
                        style: TextStyle(color: _kTextDim, fontSize: 10, fontFamily: 'monospace')),
                  ],
                )),
                GestureDetector(
                  onTap: () {
                    setState(() => _activeIdx = i);
                    widget.onKeysChanged(_keys, _activeIdx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? _kAccent.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isActive ? _kAccent.withOpacity(0.3) : _kBorder.withOpacity(0.5)),
                    ),
                    child: Text(isActive ? 'ACTIVE' : 'USE',
                        style: TextStyle(
                            color: isActive ? _kAccent : _kTextSec,
                            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _keys.removeAt(i);
                      if (_activeIdx >= _keys.length) {
                        _activeIdx = _keys.isEmpty ? 0 : _keys.length - 1;
                      }
                    });
                    widget.onKeysChanged(_keys, _activeIdx);
                  },
                  child: Icon(Icons.close, color: _kTextDim, size: 16),
                ),
              ]),
            );
          })),
          // 키 추가
          if (_keys.length < 3) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: _kText, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Name',
                    hintStyle: TextStyle(color: _kTextDim, fontSize: 11),
                    filled: true, fillColor: _kSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _keyCtrl,
                  style: const TextStyle(color: _kText, fontSize: 11, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    hintStyle: TextStyle(color: _kTextDim, fontSize: 11),
                    filled: true, fillColor: _kSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (_keyCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _keys.add({
                        'name': _nameCtrl.text.trim().isEmpty ? 'Key' : _nameCtrl.text.trim(),
                        'key': _keyCtrl.text.trim(),
                        'status': '',
                      });
                    });
                    widget.onKeysChanged(_keys, _activeIdx);
                    widget.onVerify(_keys.length - 1);
                    _nameCtrl.clear();
                    _keyCtrl.clear();
                  }
                },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _kAccent.withOpacity(0.12),
                    border: Border.all(color: _kAccent.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.add, color: _kAccent, size: 18),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
