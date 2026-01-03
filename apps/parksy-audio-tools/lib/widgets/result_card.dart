import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/analytics_service.dart';

class ResultCard extends StatelessWidget {
  final String? mp3Path;
  final String? midiPath;

  const ResultCard({
    super.key,
    this.mp3Path,
    this.midiPath,
  });

  Future<void> _shareMp3() async {
    if (mp3Path == null) return;
    AnalyticsService.instance.logFileShare('mp3');
    await Share.shareXFiles([XFile(mp3Path!)]);
  }

  Future<void> _shareMidi() async {
    if (midiPath == null) return;
    AnalyticsService.instance.logFileShare('midi');
    await Share.shareXFiles([XFile(midiPath!)]);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              size: 48,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            const Text('변환 완료!'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (mp3Path != null)
                  ElevatedButton.icon(
                    onPressed: _shareMp3,
                    icon: const Icon(Icons.audiotrack),
                    label: const Text('MP3'),
                  ),
                const SizedBox(width: 12),
                if (midiPath != null)
                  ElevatedButton.icon(
                    onPressed: _shareMidi,
                    icon: const Icon(Icons.piano),
                    label: const Text('MIDI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
