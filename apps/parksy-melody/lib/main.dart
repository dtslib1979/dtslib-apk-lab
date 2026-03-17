import 'package:flutter/material.dart';
import 'screens/melody_screen.dart';

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
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8D5B7),
          surface: Color(0xFF1A1A1A),
        ),
        useMaterial3: true,
      ),
      home: const MelodyScreen(),
    );
  }
}
