import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/transcript.dart';
import '../services/storage_service.dart';
import '../services/audio_preprocessor.dart';
import '../services/whisper_service.dart';
import 'transcript_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Transcript> _history = [];
  bool _isLoading = false;
  bool _isTranscribing = false;
  String _statusMessage = '';
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await StorageService.getHistory();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _pickAndTranscribe() async {
    // Check API key first
    final apiKey = await StorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('API key not set. Open Settings first.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ),
      );
      return;
    }

    // Pick audio file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    await _transcribeFile(file.path!, file.name, apiKey);
  }

  Future<void> _transcribeFile(
      String filePath, String fileName, String apiKey) async {
    setState(() {
      _isTranscribing = true;
      _statusMessage = 'Getting audio duration...';
      _uploadProgress = 0;
    });

    try {
      // Step 1: Get duration
      final duration = await AudioPreprocessor.getDuration(filePath);
      final audioDuration = Duration(
          seconds: duration?.toInt() ?? 0);

      // Step 2: Preprocess
      setState(() => _statusMessage =
          'Preprocessing audio (mono 16kHz)...');
      final prepResult = await AudioPreprocessor.preprocess(filePath);

      if (!prepResult.success) {
        _showError('Preprocess failed: ${prepResult.error}');
        return;
      }

      setState(() => _statusMessage =
          'Compressed: ${prepResult.inputSizeMB.toStringAsFixed(1)}MB → ${prepResult.outputSizeMB.toStringAsFixed(1)}MB (${prepResult.compressionRatio})');

      await Future.delayed(const Duration(seconds: 1));

      // Step 3: Transcribe via Whisper
      setState(() => _statusMessage = 'Uploading to Whisper API...');

      final whisper = WhisperService(apiKey: apiKey);
      final whisperResult = await whisper.transcribe(
        filePath: prepResult.outputPath!,
        language: 'ko',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _statusMessage =
                  'Uploading... ${(progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      if (!whisperResult.success) {
        _showError(whisperResult.errorMessage ?? 'Transcription failed');
        return;
      }

      setState(() => _statusMessage = 'Transcription complete!');

      // Step 4: Save transcript
      final transcript = Transcript(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        filePath: filePath,
        createdAt: DateTime.now(),
        fullText: whisperResult.text ?? '',
        segments: whisperResult.segments,
        audioDuration: audioDuration,
        language: whisperResult.language ?? 'ko',
      );

      await StorageService.saveTranscript(transcript);
      await _loadHistory();

      // Navigate to result
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TranscriptScreen(transcript: transcript),
          ),
        );
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _statusMessage = '';
          _uploadProgress = 0;
        });
      }
      // Cleanup temp files
      AudioPreprocessor.cleanup();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isTranscribing = false;
      _statusMessage = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'ChronoCall',
          style: TextStyle(
            color: Color(0xFFE8D5B7),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFFE8D5B7)),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Transcription progress
          if (_isTranscribing) _buildProgressCard(),

          // History list
          Expanded(
            child: _history.isEmpty
                ? _buildEmptyState()
                : _buildHistoryList(),
          ),
        ],
      ),
      floatingActionButton: _isTranscribing
          ? null
          : FloatingActionButton.extended(
              onPressed: _pickAndTranscribe,
              backgroundColor: const Color(0xFFE8D5B7),
              icon: const Icon(Icons.audio_file, color: Color(0xFF1A1A2E)),
              label: const Text(
                'Select Audio',
                style: TextStyle(
                    color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D5B7).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Color(0xFFE8D5B7),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: const TextStyle(color: Color(0xFFE8D5B7), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (_uploadProgress > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.white12,
              color: const Color(0xFFE8D5B7),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_in_talk, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No transcripts yet',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a call recording to transcribe',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final t = _history[index];
        final dateStr = DateFormat('MM/dd HH:mm').format(t.createdAt);
        final durStr =
            '${t.audioDuration.inMinutes}:${(t.audioDuration.inSeconds % 60).toString().padLeft(2, '0')}';
        final previewText = t.fullText.length > 80
            ? '${t.fullText.substring(0, 80)}...'
            : t.fullText;

        return Card(
          color: const Color(0xFF16213E),
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8D5B7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description,
                  color: Color(0xFFE8D5B7), size: 22),
            ),
            title: Text(
              t.fileName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '$dateStr  |  $durStr',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  previewText,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.3)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TranscriptScreen(transcript: t),
                ),
              );
            },
            onLongPress: () => _showDeleteDialog(t),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(Transcript t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete transcript?',
            style: TextStyle(color: Colors.white)),
        content: Text(t.fileName,
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFE8D5B7))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.deleteTranscript(t.id);
              await _loadHistory();
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
