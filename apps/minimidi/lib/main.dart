import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MiniMidiApp());
}

class MiniMidiApp extends StatelessWidget {
  const MiniMidiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniMidi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
