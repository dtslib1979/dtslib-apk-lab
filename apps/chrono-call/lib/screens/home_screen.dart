import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../main.dart';
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
  bool _isTranscribing = false;
  String _statusMessage = '';
  double _uploadProgress = 0;
  String? _samsungRecordingPath;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _detectSamsungPath();
    _checkIncomingIntent();
  }

  Future<void> _loadHistory() async {
    final history = await StorageService.getHistory();
    if (mounted) setState(() => _history = history);
  }

  /// Detect which Samsung call recording path exists on this device
  Future<void> _detectSamsungPath() async {
    for (final path in AppConstants.samsungRecordingPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        if (mounted) setState(() => _samsungRecordingPath = path);
        return;
      }
    }
  }

  /// Check if launched via Share Intent
  Future<void> _checkIncomingIntent() async {
    final shared = await IntentChannel.getSharedAudio();
    if (shared == null) return;

    final path = shared['path'];
    final name = shared['name'] ?? 'shared_audio';
    if (path == null) return;

    // Confirm with user before auto-transcribing
    if (!mounted) return;
    final shouldTranscribe = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Shared Audio Received',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Transcribe "$name"?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFE8D5B7))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8D5B7),
              foregroundColor: const Color(0xFF1A1A2E),
            ),
            child: const Text('Transcribe'),
          ),
        ],
      ),
    );

    if (shouldTranscribe == true) {
      final apiKey = await StorageService.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        _showError('API key not set. Open Settings first.');
        return;
      }
      await _transcribeFile(path, name, apiKey);
    }
  }

  /// Main entry: pick audio file via system picker
  Future<void> _pickAndTranscribe() async {
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

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    await _transcribeFile(file.path!, file.name, apiKey);
  }

  /// List Samsung call recordings and let user pick
  Future<void> _browseSamsungRecordings() async {
    if (_samsungRecordingPath == null) {
      _showError('Samsung recording folder not found on this device.');
      return;
    }

    final apiKey = await StorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _showError('API key not set. Open Settings first.');
      return;
    }

    final dir = Directory(_samsungRecordingPath!);
    final files = await dir
        .list()
        .where((f) =>
            f is File &&
            (f.path.endsWith('.m4a') ||
                f.path.endsWith('.amr') ||
                f.path.endsWith('.3gp') ||
                f.path.endsWith('.ogg') ||
                f.path.endsWith('.mp3') ||
                f.path.endsWith('.wav')))
        .cast<File>()
        .toList();

    // Sort newest first
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    if (files.isEmpty) {
      _showError('No call recordings found in $_samsungRecordingPath');
      return;
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<File>(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Color(0xFFE8D5B7), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Call Recordings (${files.length})',
                    style: const TextStyle(
                      color: Color(0xFFE8D5B7),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: files.length,
                itemBuilder: (ctx, i) {
                  final f = files[i];
                  final name = f.path.split('/').last;
                  final stat = f.statSync();
                  final sizeMB = stat.size / (1024 * 1024);
                  final dateStr = DateFormat('MM/dd HH:mm')
                      .format(stat.modified);

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8D5B7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.audio_file,
                          color: Color(0xFFE8D5B7), size: 20),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '$dateStr  |  ${sizeMB.toStringAsFixed(1)}MB',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11),
                    ),
                    onTap: () => Navigator.pop(ctx, f),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      await _transcribeFile(
          selected.path, selected.path.split('/').last, apiKey);
    }
  }

  /// Core transcription pipeline
  Future<void> _transcribeFile(
      String filePath, String fileName, String apiKey) async {
    if (_isTranscribing) return;

    // Validate file exists
    final file = File(filePath);
    if (!await file.exists()) {
      _showError('File not found: $filePath');
      return;
    }

    setState(() {
      _isTranscribing = true;
      _statusMessage = 'Checking audio file...';
      _uploadProgress = 0;
    });

    try {
      // Step 1: Get duration
      final duration = await AudioPreprocessor.getDuration(filePath);
      final audioDuration = Duration(seconds: duration?.toInt() ?? 0);

      if (duration != null && duration > 0) {
        setState(() => _statusMessage =
            'Duration: ${audioDuration.inMinutes}m ${audioDuration.inSeconds % 60}s');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 2: Check file size (Whisper API limit 25MB)
      setState(() => _statusMessage = 'Checking file size...');

      final prepResult = await AudioPreprocessor.preprocess(filePath);
      if (prepResult.outputSizeMB > AppConstants.maxFileSizeMB) {
        _showError(
            'File too large: '
            '${prepResult.outputSizeMB.toStringAsFixed(1)}MB '
            '(limit: ${AppConstants.maxFileSizeMB}MB). '
            'Try a shorter recording.');
        return;
      }

      setState(() => _statusMessage =
          '${prepResult.outputSizeMB.toStringAsFixed(1)}MB — ready');
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: Whisper API
      setState(() {
        _statusMessage = 'Uploading to Whisper API...';
        _uploadProgress = 0;
      });

      final whisper = WhisperService(apiKey: apiKey);
      final whisperResult = await whisper.transcribe(
        filePath: prepResult.outputPath!,
        language: 'ko',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              if (progress < 1.0) {
                _statusMessage =
                    'Uploading... ${(progress * 100).toStringAsFixed(0)}%';
              } else {
                _statusMessage = 'Waiting for transcription...';
              }
            });
          }
        },
      );

      if (!whisperResult.success) {
        _showError(whisperResult.errorMessage ?? 'Transcription failed');
        return;
      }

      // Step 4: Build transcript object
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

      // Step 5: Save to history
      await StorageService.saveTranscript(transcript);
      await _loadHistory();

      setState(() => _statusMessage = 'Done!');

      // Step 6: Auto-share to Parksy Capture if enabled
      final autoShare = await StorageService.getAutoShare();
      if (autoShare) {
        await Share.share(transcript.toShareText());
      }

      // Step 7: Navigate to result
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TranscriptScreen(transcript: transcript),
          ),
        );
      }
    } catch (e) {
      _showError('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _statusMessage = '';
          _uploadProgress = 0;
        });
      }
      AudioPreprocessor.cleanup();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isTranscribing = false;
      _statusMessage = '';
      _uploadProgress = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ──────────────────── UI ────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Row(
          children: [
            Text(
              'ChronoCall',
              style: TextStyle(
                color: Color(0xFFE8D5B7),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'v${AppConstants.version}',
              style: TextStyle(
                color: Color(0xFFE8D5B7),
                fontSize: 11,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
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
          // Samsung shortcut bar (only if detected)
          if (_samsungRecordingPath != null && !_isTranscribing)
            _buildSamsungBar(),

          // Transcription progress
          if (_isTranscribing) _buildProgressCard(),

          // History list
          Expanded(
            child: _history.isEmpty ? _buildEmptyState() : _buildHistoryList(),
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

  Widget _buildSamsungBar() {
    return InkWell(
      onTap: _browseSamsungRecordings,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E).withOpacity(0.8),
          border: Border(
            bottom: BorderSide(color: const Color(0xFFE8D5B7).withOpacity(0.15)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8D5B7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone, color: Color(0xFFE8D5B7), size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Samsung Call Recordings',
                    style: TextStyle(
                      color: Color(0xFFE8D5B7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _samsungRecordingPath!.replaceFirst('/storage/emulated/0/', ''),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.3), size: 20),
          ],
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
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: Colors.white12,
                color: const Color(0xFFE8D5B7),
                minHeight: 6,
              ),
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
          Icon(Icons.phone_in_talk,
              size: 80, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(
            'No transcripts yet',
            style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _samsungRecordingPath != null
                ? 'Tap the Samsung bar above or select a file'
                : 'Select a call recording to transcribe',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 14),
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
        final durMin = t.audioDuration.inMinutes;
        final durSec = (t.audioDuration.inSeconds % 60).toString().padLeft(2, '0');
        final durStr = '$durMin:$durSec';
        final previewText = t.fullText.length > 100
            ? '${t.fullText.substring(0, 100)}...'
            : t.fullText;

        return Dismissible(
          key: Key(t.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDelete(t),
          onDismissed: (_) async {
            await StorageService.deleteTranscript(t.id);
            await _loadHistory();
          },
          child: Card(
            color: const Color(0xFF16213E),
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TranscriptScreen(transcript: t),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8D5B7).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description,
                          color: Color(0xFFE8D5B7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.fileName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _miniTag(dateStr),
                              const SizedBox(width: 6),
                              _miniTag(durStr),
                              const SizedBox(width: 6),
                              _miniTag('${t.segments.length} seg'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            previewText,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 12,
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.white.withOpacity(0.2), size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 10,
            fontFamily: 'monospace'),
      ),
    );
  }

  Future<bool?> _confirmDelete(Transcript t) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete transcript?',
            style: TextStyle(color: Colors.white)),
        content: Text(t.fileName,
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFE8D5B7))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
