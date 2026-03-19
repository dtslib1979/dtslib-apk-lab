import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
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
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4FC3F7),
          surface: const Color(0xFF141414),
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
