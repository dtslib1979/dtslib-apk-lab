import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AivaTrimmerApp());
}

class AivaTrimmerApp extends StatelessWidget {
  const AivaTrimmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIVA Trimmer',
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
