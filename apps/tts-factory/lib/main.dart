import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TTSFactoryApp());
}

class TTSFactoryApp extends StatelessWidget {
  const TTSFactoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parksy TTS',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      primaryColor: const Color(0xFF58A6FF),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF58A6FF),
        secondary: Color(0xFF7EE787),
        surface: Color(0xFF161B22),
        error: Color(0xFFF85149),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF161B22),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1117),
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
