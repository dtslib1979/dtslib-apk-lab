import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import '../services/liner_processor.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _processing = false;
  String? _statusText;
  double _progress = 0;

  Future<void> _pickAndProcess(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 4096,
      maxHeight: 4096,
    );
    if (picked == null) return;

    setState(() {
      _processing = true;
      _statusText = 'Processing...';
      _progress = 0.1;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = '${appDir.path}/liner_output';
      await Directory(outputDir).create(recursive: true);

      setState(() {
        _progress = 0.3;
        _statusText = 'XDoG edge detection...';
      });

      final paths = await LinerProcessor.process(
        picked.path,
        outputDir: outputDir,
      );

      setState(() {
        _progress = 1.0;
        _statusText = 'Done!';
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              outputPaths: paths,
              sourcePath: picked.path,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _statusText = 'Error: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: const Color(0xFFE8D5B7),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE8D5B7).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.draw_outlined,
                  size: 56,
                  color: Color(0xFFE8D5B7),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Photo → Sketch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'XDoG line art for S Pen overdrawing',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppConstants.canvasWidth} × ${AppConstants.canvasHeight}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),

              const SizedBox(height: 48),

              // Processing indicator
              if (_processing) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFE8D5B7)),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusText ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],

              if (!_processing) ...[
                // Gallery button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickAndProcess(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text(
                      'Pick from Gallery',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8D5B7),
                      foregroundColor: const Color(0xFF1A1A2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Camera button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAndProcess(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text(
                      'Take Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE8D5B7),
                      side: BorderSide(
                        color: const Color(0xFFE8D5B7).withOpacity(0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],

              // Error text
              if (_statusText != null &&
                  !_processing &&
                  _statusText!.startsWith('Error')) ...[
                const SizedBox(height: 16),
                Text(
                  _statusText!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
