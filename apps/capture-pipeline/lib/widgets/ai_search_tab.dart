import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AiSearchTab extends StatefulWidget {
  final bool isAiConfigured;
  final bool isSearching;
  final Function(String query, String mode) onSearch;
  final String? aiAnswer;
  final String? aiError;
  final List<Map<String, dynamic>> aiReferences;
  final Function(String text)? onCopyAnswer;

  const AiSearchTab({
    super.key,
    required this.isAiConfigured,
    required this.isSearching,
    required this.onSearch,
    this.aiAnswer,
    this.aiError,
    this.aiReferences = const [],
    this.onCopyAnswer,
  });

  @override
  State<AiSearchTab> createState() => _AiSearchTabState();
}

class _AiSearchTabState extends State<AiSearchTab> {
  final TextEditingController _queryController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _searchMode = 'search';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildSearchInput(),
      _buildModeSelector(),
      _buildSearchButton(),
      Expanded(child: _buildResult()),
    ]);
  }

  Widget _buildSearchInput() {
    if (!widget.isAiConfigured) {
      return Padding(padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.psychology_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 24),
          const Text('AI 검색', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Settings에서 DeepSeek API 키를 설정하면\n저장된 로그를 AI가 분석합니다.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
        ]));
    }
    return Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Expanded(child: TextField(
        controller: _queryController,
        decoration: InputDecoration(
          hintText: '저장된 로그에 질문하기...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _queryController.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _queryController.clear(); setState(() {}); })
              : null,
          filled: true, fillColor: const Color(0xFF161B22),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _search(),
      )),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          color: _isListening ? const Color(0xFFF85149).withOpacity(0.2) : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isListening ? const Color(0xFFF85149) : const Color(0xFF30363D)),
        ),
        child: IconButton(
          icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? const Color(0xFFF85149) : Colors.grey),
          onPressed: _toggleVoiceInput,
        ),
      ),
    ]));
  }

  Widget _buildModeSelector() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
      Expanded(child: _buildModeButton('search', '검색', Icons.search, '관련 기록 찾기')),
      const SizedBox(width: 8),
      Expanded(child: _buildModeButton('generate', '종합', Icons.auto_awesome, '분석/요약')),
    ]));
  }

  Widget _buildModeButton(String mode, String label, IconData icon, String desc) {
    final isSelected = _searchMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _searchMode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF58A6FF).withOpacity(0.15) : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF30363D)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF58A6FF) : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF58A6FF) : Colors.grey)),
          ]),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildSearchButton() {
    return Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 48,
      child: ElevatedButton.icon(
        onPressed: widget.isSearching || _queryController.text.isEmpty ? null : () => widget.onSearch(_queryController.text, _searchMode),
        icon: widget.isSearching
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(_searchMode == 'search' ? Icons.psychology : Icons.auto_awesome, size: 20),
        label: Text(widget.isSearching ? '처리 중...' : (_searchMode == 'search' ? '검색' : '분석')),
        style: ElevatedButton.styleFrom(
          backgroundColor: _searchMode == 'search' ? const Color(0xFF238636) : const Color(0xFF8B5CF6),
          foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF21262D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ));
  }

  Widget _buildResult() {
    if (widget.isSearching) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: _searchMode == 'search' ? const Color(0xFF58A6FF) : const Color(0xFF8B5CF6)),
        const SizedBox(height: 16),
        Text(_searchMode == 'search' ? '검색 중...' : '분석 중...', style: const TextStyle(color: Colors.grey)),
      ]));
    }
    if (widget.aiError != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48, color: Color(0xFFF85149)),
        const SizedBox(height: 16),
        Text(widget.aiError!, style: const TextStyle(color: Color(0xFFF85149))),
      ]));
    }
    if (widget.aiAnswer == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(32),
        child: Text('질문을 입력하면 저장된 로그를 검색하여 답변합니다.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 15))));
    }
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_searchMode == 'search' ? Icons.auto_awesome : Icons.article, size: 18,
              color: _searchMode == 'search' ? const Color(0xFF58A6FF) : const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          Text(_searchMode == 'search' ? '검색 결과' : '분석 결과',
              style: TextStyle(fontWeight: FontWeight.bold, color: _searchMode == 'search' ? const Color(0xFF58A6FF) : const Color(0xFF8B5CF6))),
          const Spacer(),
          if (widget.onCopyAnswer != null)
            IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () => widget.onCopyAnswer!(widget.aiAnswer!)),
        ]),
        const SizedBox(height: 12),
        SelectableText(widget.aiAnswer!, style: const TextStyle(fontSize: 15, height: 1.6)),
      ]))),
      if (widget.aiReferences.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('참조한 기록 (${widget.aiReferences.length}개)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...widget.aiReferences.map((ref) {
          final name = ref['name'] as String? ?? '';
          final displayName = name.replaceAll('ParksyLog_', '').replaceAll('.md', '');
          return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
            dense: true, title: Text(displayName, style: const TextStyle(fontSize: 13)),
            leading: const Icon(Icons.description, size: 18, color: Color(0xFF58A6FF)),
          ));
        }),
      ],
    ]));
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) { _speech.stop(); setState(() => _isListening = false); return; }
    bool available = await _speech.initialize(
      onStatus: (s) { if (s == 'done' || s == 'notListening') setState(() => _isListening = false); },
      onError: (e) { setState(() => _isListening = false); },
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (r) => setState(() => _queryController.text = r.recognizedWords), localeId: 'ko_KR');
    }
  }

  void _search() {
    final q = _queryController.text.trim();
    if (q.isNotEmpty) widget.onSearch(q, _searchMode);
  }
}
