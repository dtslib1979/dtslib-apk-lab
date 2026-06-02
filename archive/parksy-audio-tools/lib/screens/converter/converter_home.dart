import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ConverterHome extends StatefulWidget {
  const ConverterHome({super.key});

  @override
  State<ConverterHome> createState() => _ConverterHomeState();
}

class _ConverterHomeState extends State<ConverterHome> {
  // TODO: Replace with your Cloud Run URL
  static const _api = 'https://midi-converter-XXXXX.run.app';
  final _dio = Dio();
  
  String? _name;
  String? _path;
  String _status = 'idle';
  String _stage = '';
  String? _jobId;
  String? _url;
  String? _err;
  Timer? _timer;

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (r != null && r.files.single.path != null) {
      setState(() {
        _name = r.files.single.name;
        _path = r.files.single.path;
        _status = 'ready';
        _err = null;
        _url = null;
      });
    }
  }

  Future<void> _convert() async {
    if (_path == null) return;
    setState(() {
      _status = 'uploading';
      _stage = 'Uploading...';
      _err = null;
    });
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(_path!, filename: _name),
      });
      final res = await _dio.post('$_api/v1/jobs', data: form);
      _jobId = res.data['job_id'];
      setState(() {
        _status = 'processing';
        _stage = 'Queued...';
      });
      _poll();
    } catch (e) {
      setState(() {
        _status = 'error';
        _err = e.toString();
      });
    }
  }

  void _poll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_jobId == null) return;
      try {
        final res = await _dio.get('$_api/v1/jobs/$_jobId');
        final d = res.data;
        setState(() => _stage = d['stage'] ?? '');
        if (d['status'] == 'done') {
          _timer?.cancel();
          setState(() {
            _status = 'done';
            _url = d['result']['download_url'];
          });
        } else if (d['status'] == 'error') {
          _timer?.cancel();
          setState(() {
            _status = 'error';
            _err = d['error']['message'];
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _download() async {
    if (_url == null) return;
    setState(() => _stage = 'Downloading...');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final n = _name?.replaceAll('.mp3', '.mid') ?? 'out.mid';
      final p = '${dir.path}/$n';
      await _dio.download(_url!, p);
      await Share.shareXFiles([XFile(p)], text: 'MIDI from $_name');
      setState(() => _stage = 'Shared!');
    } catch (e) {
      setState(() {
        _status = 'error';
        _err = e.toString();
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _name = null;
      _path = null;
      _status = 'idle';
      _stage = '';
      _jobId = null;
      _url = null;
      _err = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  IconData get _icon {
    switch (_status) {
      case 'uploading':
      case 'processing': return Icons.hourglass_top;
      case 'done': return Icons.check_circle;
      case 'error': return Icons.error;
      default: return Icons.music_note;
    }
  }

  Color get _color {
    switch (_status) {
      case 'uploading':
      case 'processing': return Colors.amber;
      case 'done': return Colors.tealAccent;
      case 'error': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MIDI Converter')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(_icon, size: 80, color: _color),
            const SizedBox(height: 24),
            Text(_name ?? 'No file selected',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            if (_stage.isNotEmpty)
              Text(_stage, textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400])),
            if (_err != null) ...[
              const SizedBox(height: 16),
              Text(_err!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 48),
            if (_status == 'idle' || _status == 'ready')
              ElevatedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.audio_file),
                label: const Text('Select MP3'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
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
                onPressed: _download,
                icon: const Icon(Icons.share),
                label: const Text('Save & Share'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _reset, child: const Text('Convert Another')),
            ],
            if (_status == 'error')
              ElevatedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
          ],
        ),
      ),
    );
  }
}
