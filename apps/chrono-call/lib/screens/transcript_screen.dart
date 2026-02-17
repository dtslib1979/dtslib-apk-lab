import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transcript.dart';
import '../services/storage_service.dart';

class TranscriptScreen extends StatelessWidget {
  final Transcript transcript;

  const TranscriptScreen({super.key, required this.transcript});

  @override
  Widget build(BuildContext context) {
    final durStr =
        '${transcript.audioDuration.inMinutes}:${(transcript.audioDuration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        iconTheme: const IconThemeData(color: Color(0xFFE8D5B7)),
        title: Text(
          transcript.fileName,
          style: const TextStyle(color: Color(0xFFE8D5B7), fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Copy
          IconButton(
            icon: const Icon(Icons.copy, color: Color(0xFFE8D5B7), size: 20),
            tooltip: 'Copy to clipboard',
            onPressed: () => _copyToClipboard(context),
          ),
          // Share to Parksy Capture
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFFE8D5B7), size: 20),
            tooltip: 'Share',
            onPressed: () => _shareText(context),
          ),
          // Export markdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFE8D5B7)),
            color: const Color(0xFF16213E),
            onSelected: (value) {
              if (value == 'export_md') _exportMarkdown(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'export_md',
                child: Text('Export Markdown',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Metadata bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF16213E).withOpacity(0.5),
            child: Row(
              children: [
                _metaChip(Icons.access_time, durStr),
                const SizedBox(width: 16),
                _metaChip(Icons.language,
                    transcript.language.toUpperCase()),
                const SizedBox(width: 16),
                _metaChip(Icons.segment,
                    '${transcript.segments.length} segments'),
              ],
            ),
          ),

          // Transcript body
          Expanded(
            child: transcript.segments.isNotEmpty
                ? _buildSegmentView()
                : _buildPlainView(),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFE8D5B7).withOpacity(0.6), size: 14),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 12)),
      ],
    );
  }

  Widget _buildSegmentView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transcript.segments.length,
      itemBuilder: (context, index) {
        final seg = transcript.segments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp
              SizedBox(
                width: 48,
                child: Text(
                  seg.startFormatted,
                  style: TextStyle(
                    color: const Color(0xFFE8D5B7).withOpacity(0.6),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (seg.speaker != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          seg.speaker!,
                          style: const TextStyle(
                            color: Color(0xFFE8D5B7),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      seg.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        transcript.fullText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.6,
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final text = transcript.segments.isNotEmpty
        ? transcript.segments
            .map((s) => '[${s.startFormatted}] ${s.text}')
            .join('\n')
        : transcript.fullText;

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareText(BuildContext context) {
    Share.share(transcript.toShareText());
  }

  Future<void> _exportMarkdown(BuildContext context) async {
    final path = await StorageService.exportMarkdown(transcript);
    if (context.mounted) {
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: $path')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export failed. Check storage permission.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
