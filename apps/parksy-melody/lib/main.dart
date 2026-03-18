import 'package:flutter/material.dart';
import 'screens/launcher_screen.dart';

void main() {
  runApp(const ParksyMelodyApp());
}

class ParksyMelodyApp extends StatelessWidget {
  const ParksyMelodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Melody',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE53935),
          surface: Color(0xFF141414),
        ),
        useMaterial3: true,
      ),
      home: const LauncherScreen(),
    );
  }
}
