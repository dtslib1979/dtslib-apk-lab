import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ParksyWavesyApp());
}

class ParksyWavesyApp extends StatelessWidget {
  const ParksyWavesyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy Wavesy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
