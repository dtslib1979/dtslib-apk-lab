import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, HapticFeedback, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

// ── 프리미엄 다크 팔레트 ─────────────────────────────────────
const _kBg       = Color(0xFF0A0A0F);
const _kCard     = Color(0xFF15151F);
const _kCardHi   = Color(0xFF1E1E2E);
const _kText     = Color(0xFFF0F0F5);
const _kTextSec  = Color(0xFF6B6B80);
const _kTextDim  = Color(0xFF44445A);
const _kSep      = Color(0xFF25253A);
const _kBlue     = Color(0xFF5E7CFF);
const _kGreen    = Color(0xFF30D158);
const _kRed      = Color(0xFFFF453A);
const _kGold     = Color(0xFFFFD700);
const _kCyan     = Color(0xFF64FFDA);
const _kKeyBg    = Color(0xFF1A1A2A);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  int _tabIndex = 1; // 기본 = 연락처
  List<Map<String, dynamic>> _scholars = [];
  String? _apiKey;
  String _dialDisplay = '';

  // 컨퍼런스 모드
  bool _conferenceMode = false;
  final _selectedScholars = <Map<String, dynamic>>{};

  // 애니메이션
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _loadPhonebook();
    _loadApiKey();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
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
    if (_apiKey == null || _apiKey!.isEmpty) { _showApiKeyDialog(); return; }
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => ChatScreen(scholar: scholar),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    ));
  }

  void _startConference() {
    if (_selectedScholars.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('2명 이상 선택하세요')));
      return;
    }
    if (_apiKey == null || _apiKey!.isEmpty) { _showApiKeyDialog(); return; }
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => ChatScreen(
        scholar: _selectedScholars.first,
        conferenceScholars: _selectedScholars.toList(),
      ),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    ));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                hintStyle: TextStyle(color: _kTextDim),
                filled: true, fillColor: _kCardHi,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
            child: const Text('저장', style: TextStyle(color: _kCyan, fontWeight: FontWeight.w600)),
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
    return Column(
      children: [
        const Spacer(flex: 1),
        // 로고 + 글로우
        AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, __) => ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [_kCyan, _kBlue, _kGold],
              stops: [0, _glowCtrl.value, 1],
            ).createShader(bounds),
            child: Text(
              _dialDisplay.isEmpty ? 'CHRONOCALL' : _dialDisplay,
              style: TextStyle(
                fontSize: _dialDisplay.isEmpty ? 26 : 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: _dialDisplay.isEmpty ? 8 : 3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (_dialDisplay.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('SCHOLAR HOTLINE',
                style: TextStyle(color: _kTextDim, fontSize: 10,
                    letterSpacing: 6, fontWeight: FontWeight.w300)),
          ),
        const Spacer(flex: 1),
        // 키패드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            _buildKeyRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
            const SizedBox(height: 16),
            _buildKeyRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
            const SizedBox(height: 16),
            _buildKeyRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
            const SizedBox(height: 16),
            _buildKeyRow(['*', '0', '#'], ['', '+', '']),
          ]),
        ),
        const SizedBox(height: 28),
        // 전화 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 60),
            GestureDetector(
              onTap: _callRandom,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF30D158), Color(0xFF20A040)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: _kGreen.withOpacity(0.3), blurRadius: 20)],
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(width: 12),
            if (_dialDisplay.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() =>
                    _dialDisplay = _dialDisplay.substring(0, _dialDisplay.length - 1)),
                child: SizedBox(width: 48, height: 48,
                    child: Icon(Icons.backspace_outlined, color: _kTextSec, size: 22)),
              )
            else const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        // API 키
        GestureDetector(
          onTap: _showApiKeyDialog,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.key, size: 12,
                color: _apiKey != null && _apiKey!.isNotEmpty ? _kCyan : _kTextDim),
            const SizedBox(width: 4),
            Text(_apiKey != null && _apiKey!.isNotEmpty ? 'API 연결됨' : 'API 키 설정',
                style: TextStyle(color: _kTextDim, fontSize: 11)),
          ]),
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
      onTap: () { setState(() => _dialDisplay += num); HapticFeedback.lightImpact(); },
      child: Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kKeyBg,
          border: Border.all(color: _kSep, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(num, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: _kText)),
            if (sub.isNotEmpty)
              Text(sub, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                  color: _kTextDim, letterSpacing: 2)),
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

    return Column(
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                  colors: [_kCyan, _kBlue]).createShader(b),
              child: const Text('연락처',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const Spacer(),
            // 컨퍼런스 모드 토글
            GestureDetector(
              onTap: () => setState(() {
                _conferenceMode = !_conferenceMode;
                if (!_conferenceMode) _selectedScholars.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _conferenceMode ? _kGold.withOpacity(0.15) : _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _conferenceMode ? _kGold.withOpacity(0.5) : _kSep),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.groups, size: 14,
                      color: _conferenceMode ? _kGold : _kTextSec),
                  const SizedBox(width: 4),
                  Text(_conferenceMode ? '컨퍼런스' : '1:1',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: _conferenceMode ? _kGold : _kTextSec)),
                ]),
              ),
            ),
          ]),
        ),
        if (_conferenceMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('학자를 2~4명 선택 후 컨퍼런스 시작',
                style: TextStyle(color: _kTextDim, fontSize: 11)),
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
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Text(entry.key,
                      style: TextStyle(color: _kBlue.withOpacity(0.7), fontSize: 12,
                          fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                // 학자
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kSep.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: entry.value.asMap().entries.map((e) {
                      final s = e.value;
                      final isLast = e.key == entry.value.length - 1;
                      final isSelected = _selectedScholars.contains(s);
                      return Column(children: [
                        InkWell(
                          onTap: () {
                            if (_conferenceMode) {
                              setState(() {
                                if (isSelected) { _selectedScholars.remove(s); }
                                else if (_selectedScholars.length < 4) { _selectedScholars.add(s); }
                              });
                            } else { _call(s); }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: isSelected ? _kGold.withOpacity(0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(children: [
                              // 프로필
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: isSelected
                                      ? const LinearGradient(colors: [_kGold, Color(0xFFFFA000)])
                                      : LinearGradient(colors: [_kCardHi, _kCard]),
                                  border: isSelected
                                      ? Border.all(color: _kGold, width: 2) : null,
                                ),
                                child: Center(child: Text(s['emoji'],
                                    style: const TextStyle(fontSize: 20))),
                              ),
                              const SizedBox(width: 12),
                              // 이름
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(s['nameKr'] ?? s['name'],
                                        style: TextStyle(fontSize: 15, color: _kText,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text(s['name'],
                                        style: TextStyle(fontSize: 10, color: _kTextDim)),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(s['tagline'],
                                      style: TextStyle(color: _kTextSec, fontSize: 11),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              )),
                              // 전화/체크
                              if (_conferenceMode)
                                Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
                                    color: isSelected ? _kGold : _kTextDim, size: 22)
                              else
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(17),
                                    color: _kGreen.withOpacity(0.1),
                                  ),
                                  child: const Icon(Icons.call, color: _kGreen, size: 16),
                                ),
                            ]),
                          ),
                        ),
                        if (!isLast) Padding(
                          padding: const EdgeInsets.only(left: 70),
                          child: Divider(height: 1, color: _kSep.withOpacity(0.3)),
                        ),
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

  // ── 컨퍼런스 바 ─────────────────────────────────────────────
  Widget _buildConferenceBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _kCard,
        border: Border(top: BorderSide(color: _kGold.withOpacity(0.3))),
      ),
      child: Row(children: [
        // 선택된 학자 아바타
        ...(_selectedScholars.map((s) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [_kGold, Color(0xFFFFA000)]),
            ),
            child: Center(child: Text(s['emoji'], style: const TextStyle(fontSize: 16))),
          ),
        ))),
        const Spacer(),
        Text('${_selectedScholars.length}/4',
            style: TextStyle(color: _kGold, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        // 컨퍼런스 시작 버튼
        GestureDetector(
          onTap: _startConference,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kGold, Color(0xFFFFA000)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _kGold.withOpacity(0.3), blurRadius: 12)],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.groups, color: Colors.black, size: 16),
              SizedBox(width: 4),
              Text('START', style: TextStyle(color: Colors.black,
                  fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── 녹취록 ──────────────────────────────────────────────────
  List<FileSystemEntity> _recordings = [];

  Future<void> _loadRecordings() async {
    final dir = Directory('/sdcard/Download/ChronoCall');
    if (await dir.exists()) {
      final files = dir.listSync()
          ..sort((a, b) => b.path.compareTo(a.path));
      setState(() => _recordings = files);
    }
  }

  Widget _buildRecents() {
    if (_recordings.isEmpty) _loadRecordings();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                  colors: [_kCyan, _kBlue]).createShader(b),
              child: const Text('녹취록',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () { _recordings.clear(); _loadRecordings(); },
              child: Icon(Icons.refresh, color: _kTextSec, size: 20),
            ),
          ]),
        ),
        Expanded(
          child: _recordings.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description, size: 48, color: _kTextDim.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text('녹취록 없음', style: TextStyle(color: _kTextSec, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('통화 후 자동 저장됩니다',
                        style: TextStyle(color: _kTextDim, fontSize: 12)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recordings.length,
                  itemBuilder: (_, i) {
                    final file = _recordings[i];
                    final name = file.path.split('/').last;
                    final stat = file.statSync();
                    final date = stat.modified;
                    final isMd = name.endsWith('.md');
                    final isAudio = name.endsWith('.m4a') || name.endsWith('.mp3');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kSep.withOpacity(0.3)),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isMd ? Icons.description : isAudio ? Icons.audiotrack : Icons.insert_drive_file,
                          color: isMd ? _kCyan : isAudio ? _kGold : _kTextSec, size: 24),
                        title: Text(name,
                            style: const TextStyle(color: _kText, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}  ·  ${(stat.size / 1024).toStringAsFixed(0)} KB',
                            style: TextStyle(color: _kTextDim, fontSize: 10)),
                        trailing: isAudio
                            ? GestureDetector(
                                onTap: () => _playRecording(file.path),
                                child: Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _kGold.withOpacity(0.15)),
                                  child: const Icon(Icons.play_arrow, color: _kGold, size: 20)),
                              )
                            : Icon(Icons.chevron_right, color: _kTextDim, size: 18),
                        onTap: () {
                          if (isMd) {
                            _showTranscript(file.path);
                          } else if (isAudio) {
                            _playRecording(file.path);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static const _voiceCh = MethodChannel('com.parksy.chronocall/voice');

  void _playRecording(String path) async {
    try {
      await _voiceCh.invokeMethod('playFile', {'path': path});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('재생 중: ${path.split('/').last}'),
            backgroundColor: _kGreen.withOpacity(0.8)));
    } catch (_) {}
  }

  void _showTranscript(String path) async {
    try {
      final content = await File(path).readAsString();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _kCard,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                const Icon(Icons.description, color: _kCyan, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(path.split('/').last,
                    style: const TextStyle(color: _kText, fontSize: 14,
                        fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 16),
              Text(content, style: TextStyle(color: _kText.withOpacity(0.8),
                  fontSize: 13, height: 1.6)),
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
        color: _kCard,
        border: Border(top: BorderSide(color: _kSep, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTab(0, Icons.dialpad, '키패드'),
          _buildTab(1, Icons.contacts, '연락처'),
          _buildTab(2, Icons.description, '녹취록'),
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
          Icon(icon, size: 22, color: active ? _kCyan : _kTextDim),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10,
              color: active ? _kCyan : _kTextDim, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
