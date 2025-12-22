import 'package:flutter/material.dart';

void main() {
  runApp(const OverlayDualSubApp());
}

class OverlayDualSubApp extends StatelessWidget {
  const OverlayDualSubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Overlay Dual Sub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overlay Dual Sub'),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'S Pen Overlay v1.0.0',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 8),
            Text('Flutter + Kotlin Hybrid'),
          ],
        ),
      ),
    );
  }
}
