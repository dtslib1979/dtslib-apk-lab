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
      systemNavigationBarColor: Color(0xFF08080D),
      systemNavigationBarIconBrightness: Brightness.light,
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
        scaffoldBackgroundColor: const Color(0xFF08080D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF64FFDA),
          secondary: Color(0xFF5E7CFF),
          surface: Color(0xFF12121A),
          onSurface: Color(0xFFF0F0F5),
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const LandingScreen(),
    );
  }
}
