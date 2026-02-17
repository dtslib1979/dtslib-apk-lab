import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transcript.dart';
import '../services/storage_service.dart';

class TranscriptScreen extends StatefulWidget {
  final Transcript transcript;

  const TranscriptScreen({super.key, required this.transcript});

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _playerReady = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int? _activeSegmentIndex;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final file = File(widget.transcript.filePath);
    if (!await file.exists()) return;

    try {
      final duration = await _player.setFilePath(widget.transcript.filePath);
      if (duration != null) {
        setState(() {
          _duration = duration;
          _playerReady = true;
        });
      }

      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
            _activeSegmentIndex = _findActiveSegment(pos);
          });
        }
      });

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });
    } catch (e) {
      // File may not be accessible, player won't be shown
    }
  }

  int? _findActiveSegment(Duration position) {
    final sec = position.inMilliseconds / 1000.0;
    for (int i = 0; i < widget.transcript.segments.length; i++) {
      final seg = widget.transcript.segments[i];
      if (sec >= seg.start && sec <= seg.end) return i;
    }
    return null;
  }

  Future<void> _seekToSegment(int index) async {
    if (!_playerReady) return;
    final seg = widget.transcript.segments[index];
    await _player.seek(Duration(milliseconds: (seg.start * 1000).toInt()));
    if (!_isPlaying) await _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transcript;
    final durStr =
        '${t.audioDuration.inMinutes}:${(t.audioDuration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        iconTheme: const IconThemeData(color: Color(0xFFE8D5B7)),
        title: Text(
          t.fileName,
          style: const TextStyle(color: Color(0xFFE8D5B7), fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: Color(0xFFE8D5B7), size: 20),
            tooltip: 'Copy',
            onPressed: () => _copyToClipboard(context),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFFE8D5B7), size: 20),
            tooltip: 'Share to Capture',
            onPressed: () => _shareText(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFE8D5B7)),
            color: const Color(0xFF16213E),
            onSelected: (value) {
              switch (value) {
                case 'export_md':
                  _exportMarkdown(context);
                  break;
                case 'copy_segments':
                  _copySegmentsWithTimestamps(context);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'export_md',
                child: Row(
                  children: [
                    Icon(Icons.save_alt, color: Colors.white54, size: 18),
                    SizedBox(width: 8),
                    Text('Export Markdown',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_segments',
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.white54, size: 18),
                    SizedBox(width: 8),
                    Text('Copy with timestamps',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF16213E).withOpacity(0.5),
            child: Row(
              children: [
                _metaChip(Icons.access_time, durStr),
                const SizedBox(width: 12),
                _metaChip(Icons.language, t.language.toUpperCase()),
                const SizedBox(width: 12),
                _metaChip(Icons.segment, '${t.segments.length} seg'),
                const Spacer(),
                _metaChip(Icons.text_snippet,
                    '${t.fullText.length} chars'),
              ],
            ),
          ),

          // Audio player (if file exists)
          if (_playerReady) _buildPlayer(),

          // Transcript body
          Expanded(
            child: t.segments.isNotEmpty
                ? _buildSegmentView()
                : _buildPlainView(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final posStr = _fmtDuration(_position);
    final durStr = _fmtDuration(_duration);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE8D5B7).withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Play/Pause
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE8D5B7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: const Color(0xFF1A1A2E),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Position label
          SizedBox(
            width: 40,
            child: Text(
              posStr,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
          // Seek bar
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: const Color(0xFFE8D5B7),
                inactiveTrackColor: Colors.white12,
                thumbColor: const Color(0xFFE8D5B7),
                overlayColor: const Color(0xFFE8D5B7).withOpacity(0.2),
              ),
              child: Slider(
                value: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds
                        .clamp(0, _duration.inMilliseconds)
                        .toDouble()
                    : 0,
                max: _duration.inMilliseconds > 0
                    ? _duration.inMilliseconds.toDouble()
                    : 1,
                onChanged: (val) {
                  _player.seek(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
          ),
          // Duration label
          SizedBox(
            width: 40,
            child: Text(
              durStr,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFE8D5B7).withOpacity(0.5), size: 13),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ],
    );
  }

  Widget _buildSegmentView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.transcript.segments.length,
      itemBuilder: (context, index) {
        final seg = widget.transcript.segments[index];
        final isActive = _activeSegmentIndex == index;

        return GestureDetector(
          onTap: () => _seekToSegment(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFE8D5B7).withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(
                      color: const Color(0xFFE8D5B7).withOpacity(0.2))
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timestamp (tappable to seek)
                SizedBox(
                  width: 48,
                  child: Text(
                    seg.startFormatted,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFFE8D5B7)
                          : const Color(0xFFE8D5B7).withOpacity(0.4),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
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
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.85),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        widget.transcript.fullText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.6,
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.transcript.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text copied'), duration: Duration(seconds: 2)),
    );
  }

  void _copySegmentsWithTimestamps(BuildContext context) {
    final text = widget.transcript.segments
        .map((s) => '[${s.startFormatted}] ${s.text}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Copied with timestamps'),
          duration: Duration(seconds: 2)),
    );
  }

  void _shareText() {
    Share.share(widget.transcript.toShareText());
  }

  Future<void> _exportMarkdown(BuildContext context) async {
    final path = await StorageService.exportMarkdown(widget.transcript);
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
