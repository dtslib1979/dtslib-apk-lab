import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants.dart';
import 'screens/launcher_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 고정
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ParksyStudioApp());
}

class ParksyStudioApp extends StatelessWidget {
  const ParksyStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConstants.kBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppConstants.kAccent,
          surface: AppConstants.kSurface,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const LauncherScreen(),
    );
  }
}
