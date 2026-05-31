

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ToolsTab extends StatefulWidget {
  final bool isExporting;
  final String? exportResult;
  final bool isGeneratingMCP;
  final String? mcpResult;
  final VoidCallback onExportJsonl;
  final VoidCallback onGenerateProfile;
  final VoidCallback onGenerateMCP;

  const ToolsTab({
    super.key,
    required this.isExporting,
    this.exportResult,
    required this.isGeneratingMCP,
    this.mcpResult,
    required this.onExportJsonl,
    required this.onGenerateProfile,
    required this.onGenerateMCP,
  });

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab> {
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: const Color(0xFF58A6FF)),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF))),
    ]);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey[500]), const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])), const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF7EE787))),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // JSONL Converter
      _buildSectionHeader('텍스트 변환기', Icons.transform),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.code, size: 20, color: Color(0xFF58A6FF)), SizedBox(width: 8),
          Text('로그 → JSONL 변환', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
        const SizedBox(height: 8),
        Text('저장된 로그를 LLAMA/GPT 파인튜닝 포맷으로 변환합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: widget.isExporting ? null : widget.onExportJsonl,
            icon: widget.isExporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download, size: 20),
            label: Text(widget.isExporting ? '변환 중...' : '전체 JSONL 내보내기'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636), foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF21262D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        if (widget.exportResult != null && !widget.exportResult!.contains('프로파일')) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D))),
            child: Text(widget.exportResult!, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
        ],
      ]))),

      const SizedBox(height: 32),

      // Wording Profiler
      _buildSectionHeader('워딩 프로파일러', Icons.person_search),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.auto_awesome, size: 20, color: Color(0xFF8B5CF6)), SizedBox(width: 8),
          Text('박씨 워딩 프로파일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
        const SizedBox(height: 8),
        Text('대화 로그를 분석하여 말투/워딩/성향 프로파일을 추출합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48,
          child: OutlinedButton.icon(
            onPressed: widget.onGenerateProfile,
            icon: const Icon(Icons.construction, size: 20),
            label: const Text('프로파일 추출'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        if (widget.exportResult != null && widget.exportResult!.contains('프로파일')) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D))),
            child: Text(widget.exportResult!, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
        ],
      ]))),

      const SizedBox(height: 32),

      // MCP Generator
      _buildSectionHeader('MCP 서버 생성기', Icons.dns),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.terminal, size: 20, color: Color(0xFFF59E0B)), SizedBox(width: 8),
          Text('mcp-parksy-v1.js 생성', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
        const SizedBox(height: 8),
        Text('워딩 프로파일을 기반으로 박씨 전용 MCP 서버 코드를 생성합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48,
          child: OutlinedButton.icon(
            onPressed: widget.isGeneratingMCP ? null : widget.onGenerateMCP,
            icon: widget.isGeneratingMCP
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.dns, size: 20),
            label: Text(widget.isGeneratingMCP ? '생성 중...' : 'MCP 서버 생성'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        if (widget.mcpResult != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D))),
            child: SelectableText(widget.mcpResult!, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
        ],
      ]))),

      const SizedBox(height: 32),

      // Language Converter
      _buildSectionHeader('언어 변환기', Icons.translate),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.g_translate, size: 20, color: Color(0xFF7EE787)), SizedBox(width: 8),
          Text('한국어 ↔ 영어', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
        const SizedBox(height: 8),
        Text('저장된 로그를 영어 파인튜닝 데이터로 변환합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48,
          child: OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ML Kit 번역 — Google Play Services 필요'))),
            icon: const Icon(Icons.translate, size: 20),
            label: const Text('영어 JSONL 변환'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF7EE787),
                side: const BorderSide(color: Color(0xFF7EE787)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ]))),

      const SizedBox(height: 32),

      // System Status
      _buildSectionHeader('시스템 상태', Icons.memory),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildInfoRow(Icons.psychology, 'AI 엔진', '온디바이스 (로컬 텍스트 검색)'),
        _buildInfoRow(Icons.transform, '포맷 변환', 'JSONL 지원'),
        _buildInfoRow(Icons.cloud_off, '네트워크', '오프라인 작동'),
        _buildInfoRow(Icons.monetization_on, '비용', '과금 0원/월'),
      ]))),
    ]));
  }
}
