import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/constants.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ParksyLinerApp());
}

class ParksyLinerApp extends StatelessWidget {
  const ParksyLinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          foregroundColor: Color(0xFFE8D5B7),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8D5B7),
          surface: Color(0xFF16213E),
        ),
      ),
      home: const PermissionGate(),
    );
  }
}

class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _granted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final camera = await Permission.camera.status;
    final storage = await Permission.storage.status;

    if (camera.isGranted && storage.isGranted) {
      setState(() {
        _granted = true;
        _checking = false;
      });
      return;
    }

    final results = await [
      Permission.camera,
      Permission.storage,
    ].request();

    setState(() {
      _granted = results.values.every((s) => s.isGranted);
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_granted) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    size: 48, color: Color(0xFFE8D5B7)),
                const SizedBox(height: 16),
                const Text(
                  'Camera & Storage permissions required',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _checkPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8D5B7),
                    foregroundColor: const Color(0xFF1A1A2E),
                  ),
                  child: const Text('Grant Permissions'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
