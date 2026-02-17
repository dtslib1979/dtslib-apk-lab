import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChronoCallApp());
}

class ChronoCallApp extends StatelessWidget {
  const ChronoCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy ChronoCall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE8D5B7),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8D5B7),
          secondary: Color(0xFF16213E),
          surface: Color(0xFF16213E),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF16213E),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const PermissionGate(),
    );
  }
}

/// Permission gate: checks audio/storage permission before showing home.
/// Handles both Android 13+ (READ_MEDIA_AUDIO) and older (READ_EXTERNAL_STORAGE).
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _granted = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when user returns from app settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_granted) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    bool ok = false;

    // Android 13+ (API 33): READ_MEDIA_AUDIO
    final audioStatus = await Permission.audio.status;
    if (audioStatus.isGranted) {
      ok = true;
    } else {
      // Fallback: READ_EXTERNAL_STORAGE (Android 12 and below)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) ok = true;
    }

    // MANAGE_EXTERNAL_STORAGE as last resort (for direct path access)
    if (!ok) {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) ok = true;
    }

    if (mounted) {
      setState(() {
        _checking = false;
        _granted = ok;
      });
    }
  }

  Future<void> _requestPermissions() async {
    // Try READ_MEDIA_AUDIO first (Android 13+)
    var status = await Permission.audio.request();
    if (status.isGranted) {
      if (mounted) setState(() => _granted = true);
      return;
    }

    // Fallback: READ_EXTERNAL_STORAGE
    status = await Permission.storage.request();
    if (status.isGranted) {
      if (mounted) setState(() => _granted = true);
      return;
    }

    // Check permanently denied
    if (status.isPermanentlyDenied) {
      if (mounted) setState(() => _permanentlyDenied = true);
      return;
    }

    // Last resort: MANAGE_EXTERNAL_STORAGE
    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      if (mounted) setState(() => _granted = true);
      return;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) setState(() => _permanentlyDenied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE8D5B7)),
        ),
      );
    }

    if (_granted) {
      return const HomeScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open,
                  size: 64, color: Colors.white.withOpacity(0.4)),
              const SizedBox(height: 24),
              const Text(
                'Storage Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ChronoCall needs access to audio files\nto transcribe call recordings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), height: 1.5),
              ),
              const SizedBox(height: 32),
              if (_permanentlyDenied) ...[
                Text(
                  'Permission was denied permanently.\nPlease enable it in system settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.orange.withOpacity(0.8),
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Open Settings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE8D5B7),
                    side: const BorderSide(color: Color(0xFFE8D5B7)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else
                ElevatedButton(
                  onPressed: _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8D5B7),
                    foregroundColor: const Color(0xFF1A1A2E),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Grant Permission',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Platform channel helper for intent communication
class IntentChannel {
  static const _channel = MethodChannel('com.parksy.chronocall/intent');

  /// Check if app was launched via Share Intent with audio file.
  /// Returns {"path": "/local/path", "name": "filename.m4a"} or null.
  static Future<Map<String, String>?> getSharedAudio() async {
    try {
      final result = await _channel.invokeMethod('getSharedAudio');
      if (result == null) return null;
      return Map<String, String>.from(result as Map);
    } catch (e) {
      return null;
    }
  }

  /// Copy a content:// URI to local cache (for FFmpeg compatibility).
  static Future<Map<String, String>?> copyUriToLocal(String uri) async {
    try {
      final result =
          await _channel.invokeMethod('copyUriToLocal', {'uri': uri});
      if (result == null) return null;
      return Map<String, String>.from(result as Map);
    } catch (e) {
      return null;
    }
  }

  /// Get file metadata (size, exists, name).
  static Future<Map<String, dynamic>?> getAudioMetadata(String path) async {
    try {
      final result =
          await _channel.invokeMethod('getAudioMetadata', {'path': path});
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return null;
    }
  }
}
