import 'package:flutter/material.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIVA Trimmer')),
      body: const Center(
        child: Text('Coming soon...'),
      ),
    );
  }
}
