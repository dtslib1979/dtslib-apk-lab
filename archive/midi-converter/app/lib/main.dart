import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MidiConverterApp());
}

class MidiConverterApp extends StatelessWidget {
  const MidiConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIDI Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
