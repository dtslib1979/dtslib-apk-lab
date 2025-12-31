import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/subtitle_provider.dart';
import 'screens/home_screen.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await AppConfig.init();

  runApp(const ParksyGlotApp());
}

class ParksyGlotApp extends StatelessWidget {
  const ParksyGlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SubtitleProvider()),
      ],
      child: MaterialApp(
        title: 'Parksy Glot',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Pretendard',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
