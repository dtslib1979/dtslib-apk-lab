import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/analytics_service.dart';
import 'services/connectivity_service.dart';

/// Firebase enabled flag - set to true when google-services.json is added
const bool kFirebaseEnabled = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase if enabled
  if (kFirebaseEnabled) {
    await _initFirebase();
  }

  // Initialize core services (always)
  await ConnectivityService.instance.init();
  
  // Analytics init is safe even without Firebase
  await AnalyticsService.instance.init();

  runApp(const ParksyAudioApp());
}

Future<void> _initFirebase() async {
  try {
    // Dynamic import to avoid build errors
    final firebase = await _loadFirebase();
    if (firebase != null) {
      await firebase.initializeApp();
      debugPrint('[Firebase] Initialized');
    }
  } catch (e) {
    debugPrint('[Firebase] Not available: $e');
  }
}

Future<dynamic> _loadFirebase() async {
  try {
    // This will fail at runtime if google-services.json is missing
    final module = await import('package:firebase_core/firebase_core.dart');
    return module.Firebase;
  } catch (e) {
    return null;
  }
}

class ParksyAudioApp extends StatelessWidget {
  const ParksyAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Audio Tools',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      builder: (context, child) {
        // Global error boundary
        ErrorWidget.builder = (details) => _ErrorScreen(details: details);
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// Production-friendly error screen
class _ErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const _ErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                '문제가 발생했습니다',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '앱을 다시 시작해주세요.\n문제가 계속되면 개발자에게 문의하세요.',
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Text(
                  details.exceptionAsString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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
