import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/landing_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    runApp(const ChronoCallApp());
  }, (error, stack) {
    debugPrint('ChronoCall error: $error\n$stack');
  });
}

class ChronoCallApp extends StatelessWidget {
  const ChronoCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChronoCall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF0A84FF),
          surface: const Color(0xFF1C1C1E),
        ),
        useMaterial3: true,
      ),
      home: const LandingScreen(),
    );
  }
}
