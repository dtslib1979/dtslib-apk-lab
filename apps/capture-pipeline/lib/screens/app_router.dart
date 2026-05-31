import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_config.dart';
import 'share_handler.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  static const platform = MethodChannel('com.parksy.capture/share');
  bool _isLoading = true;
  bool _isShareIntent = false;
  bool _isFirstLaunch = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ApiConfig.load();
    await _checkLaunchMode();
  }

  Future<void> _checkLaunchMode() async {
    try {
      final isShare = await platform.invokeMethod<bool>('isShareIntent');
      final stats = await platform.invokeMethod<Map>('getStats');
      setState(() {
        _isShareIntent = isShare ?? false;
        _isFirstLaunch = (stats?['totalLogs'] ?? 0) == 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isShareIntent = false; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.catching_pokemon, size: 48, color: Color(0xFF58A6FF)),
            SizedBox(height: 16),
            Text('Parksy Capture', style: TextStyle(fontSize: 18)),
          ],
        )),
      );
    }
    if (_isShareIntent) return const ShareHandler();
    if (_isFirstLaunch) return const OnboardingScreen();
    return const HomeScreen();
  }
}
