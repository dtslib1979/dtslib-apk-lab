import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // TODO: Replace with your Cloud Run URL
  static const apiUrl = 'https://midi-converter-XXXXX.run.app';
  
  final dio = Dio();
  
  String? _fileName;
  String? _filePath;
  String _status = 'idle';
  String _stage = '';
  String? _jobId;
  String? _downloadUrl;
  String? _error;
  Timer? _pollTimer;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    
    if (result != null && result.files.single.path != null) {
      setState(() {
        _fileName = result.files.single.name;
        _filePath = result.files.single.path;
        _status = 'ready';
        _error = null;
        _downloadUrl = null;
      });
    }
  }

  Future<void> _convert() async {
    if (_filePath == null) return;
    
    setState(() {
      _status = 'uploading';
      _stage = 'Uploading...';
      _error = null;
    });
    
    try {
      // Upload
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_filePath!, filename: _fileName),
      });
      
      final res = await dio.post('$apiUrl/v1/jobs', data: formData);
      _jobId = res.data['job_id'];
      
      setState(() {
        _status = 'processing';
        _stage = 'Queued...';
      });
      
      // Start polling
      _startPolling();
      
    } catch (e) {
      setState(() {
        _status = 'error';
        _error = e.toString();
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_jobId == null) return;
      
      try {
        final res = await dio.get('$apiUrl/v1/jobs/$_jobId');
        final data = res.data;
        
        setState(() {
          _stage = data['stage'] ?? '';
        });
        
        if (data['status'] == 'done') {
          _pollTimer?.cancel();
          setState(() {
            _status = 'done';
            _downloadUrl = data['result']['download_url'];
          });
        } else if (data['status'] == 'error') {
          _pollTimer?.cancel();
          setState(() {
            _status = 'error';
            _error = data['error']['message'];
          });
        }
      } catch (e) {
        // Keep polling on network error
      }
    });
  }

  Future<void> _downloadAndShare() async {
    if (_downloadUrl == null) return;
    
    setState(() => _stage = 'Downloading...');
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = _fileName?.replaceAll('.mp3', '.mid') ?? 'output.mid';
      final path = '${dir.path}/$name';
      
      await dio.download(_downloadUrl!, path);
      
      await Share.shareXFiles(
        [XFile(path)],
        text: 'MIDI converted from $_fileName',
      );
      
      setState(() => _stage = 'Shared!');
    } catch (e) {
      setState(() {
        _status = 'error';
        _error = e.toString();
      });
    }
  }

  void _reset() {
    _pollTimer?.cancel();
    setState(() {
      _fileName = null;
      _filePath = null;
      _status = 'idle';
      _stage = '';
      _jobId = null;
      _downloadUrl = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIDI Converter'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status icon
            Icon(
              _statusIcon,
              size: 80,
              color: _statusColor,
            ),
            const SizedBox(height: 24),
            
            // File name
            Text(
              _fileName ?? 'No file selected',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            
            // Stage
            if (_stage.isNotEmpty)
              Text(
                _stage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
            
            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            
            const SizedBox(height: 48),
            
            // Action buttons
            if (_status == 'idle' || _status == 'ready')
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.audio_file),
                label: const Text('Select MP3'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            
            if (_status == 'ready') ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _convert,
                icon: const Icon(Icons.transform),
                label: const Text('Convert to MIDI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
            
            if (_status == 'done') ...[
              ElevatedButton.icon(
                onPressed: _downloadAndShare,
                icon: const Icon(Icons.share),
                label: const Text('Save & Share MIDI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _reset,
                child: const Text('Convert Another'),
              ),
            ],
            
            if (_status == 'error')
              ElevatedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'uploading':
      case 'processing':
        return Icons.hourglass_top;
      case 'done':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      default:
        return Icons.music_note;
    }
  }

  Color get _statusColor {
    switch (_status) {
      case 'uploading':
      case 'processing':
        return Colors.amber;
      case 'done':
        return Colors.tealAccent;
      case 'error':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
