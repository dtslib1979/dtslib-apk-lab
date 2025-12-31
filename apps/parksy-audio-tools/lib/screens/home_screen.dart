import 'package:flutter/material.dart';
import '../services/file_manager.dart';
import 'capture/capture_screen.dart';
import 'converter/converter_screen.dart';
import 'trimmer/trimmer_screen.dart';

/// Home screen with tab navigation
/// Uses IndexedStack to preserve state across tabs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Lazy-initialized screens to preserve state
  final List<Widget> _screens = const [
    CaptureScreen(),   // Track A: Overlay Recording → MIDI
    ConverterScreen(), // Track B: File → MIDI
    TrimmerScreen(),   // Legacy: File → WAV
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cleanupOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background - could save state here
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground
    }
  }

  /// Cleanup old temp files on app start
  Future<void> _cleanupOnStart() async {
    final deleted = await FileManager.instance.cleanupOldFiles();
    if (deleted > 0) {
      debugPrint('Cleaned up $deleted old temp files');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack preserves state of all tabs
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_outlined),
            selectedIcon: Icon(Icons.mic),
            label: '녹음→MIDI',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '파일→MIDI',
          ),
          NavigationDestination(
            icon: Icon(Icons.content_cut_outlined),
            selectedIcon: Icon(Icons.content_cut),
            label: '트림',
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }
}
