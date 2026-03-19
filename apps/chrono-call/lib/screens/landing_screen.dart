import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _breathAnim = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));
    _loadApiKey();
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _apiKey = prefs.getString('gemini_api_key'));
  }

  void _showApiKeyDialog() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gemini API Key',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Get your free key from\naistudio.google.com',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                hintStyle: TextStyle(color: Colors.grey[300]),
                filled: true, fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!)),
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
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _startCall() {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _showApiKeyDialog();
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // 로고 + 타이틀
            const Text('CHRONOCALL',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                )),
            const SizedBox(height: 6),
            Text('AI Scholar Hotline',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                )),

            const Spacer(flex: 2),

            // 전화 버튼 (아이폰 스타일)
            AnimatedBuilder(
              animation: _breathAnim,
              builder: (_, __) => GestureDetector(
                onTap: _startCall,
                child: Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF34C759),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF34C759).withOpacity(0.3 * _breathAnim.value),
                        blurRadius: 30 * _breathAnim.value,
                        spreadRadius: 5 * _breathAnim.value,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call, color: Colors.white, size: 36),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Tap to call',
                style: TextStyle(color: Colors.grey[500], fontSize: 14,
                    fontWeight: FontWeight.w500)),

            const Spacer(flex: 1),

            // 하단 정보
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _featureChip(Icons.mic, 'Voice'),
                      const SizedBox(width: 20),
                      _featureChip(Icons.translate, 'Translate'),
                      const SizedBox(width: 20),
                      _featureChip(Icons.save_alt, 'Save'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('No screen needed · Earbud control',
                      style: TextStyle(color: Colors.grey[300], fontSize: 11)),
                ],
              ),
            ),

            // API 키 설정
            TextButton(
              onPressed: _showApiKeyDialog,
              child: Text(
                _apiKey != null && _apiKey!.isNotEmpty
                    ? 'API Key: ••••${_apiKey!.substring(_apiKey!.length - 4)}'
                    : 'Set API Key',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text('v3.3', style: TextStyle(color: Colors.grey[200], fontSize: 10)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10,
            fontWeight: FontWeight.w500)),
      ],
    );
  }
}
