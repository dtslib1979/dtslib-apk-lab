import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const CaptureApp());
}

class CaptureApp extends StatelessWidget {
  const CaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Capture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF50),
          secondary: Color(0xFF81C784),
        ),
      ),
      home: const HelpScreen(),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Title
              const Text(
                'Parksy Capture',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How to use',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),

              const SizedBox(height: 40),

              // Instructions
              _buildStep('1', 'In any app or web page, highlight text'),
              const SizedBox(height: 16),
              _buildStep('2', 'Tap Share'),
              const SizedBox(height: 16),
              _buildStep('3', 'Choose "Parksy Capture"'),
              const SizedBox(height: 16),
              _buildStep('4', 'Text is saved to Downloads\n(and GitHub if configured)'),

              const SizedBox(height: 40),

              // Warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Do NOT use page link share.\nAlways select text first.',
                        style: TextStyle(
                          color: Colors.orange[200],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.folder_open,
                      label: 'Open Downloads',
                      onTap: () => _openDownloads(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.share,
                      label: 'Test Share',
                      onTap: () => _shareTestText(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Version
              Center(
                child: Text(
                  'v2.0.0 • Clipboard-free capture',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openDownloads(BuildContext context) {
    // Android Intent to open Downloads folder
    const platform = MethodChannel('com.parksy.capture/share');
    platform.invokeMethod('openDownloads').catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open Downloads/parksy-logs manually')),
      );
    });
  }

  void _shareTestText(BuildContext context) {
    final testText = '''This is a test capture from Parksy Capture.

If you see this file saved in Downloads/parksy-logs, the app is working correctly.

Timestamp: ${DateTime.now().toIso8601String()}
''';

    Share.share(testText, context);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Colors.white70, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Share {
  static void share(String text, BuildContext context) {
    const platform = MethodChannel('com.parksy.capture/share');
    platform.invokeMethod('shareText', {'text': text}).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share failed')),
      );
    });
  }
}
