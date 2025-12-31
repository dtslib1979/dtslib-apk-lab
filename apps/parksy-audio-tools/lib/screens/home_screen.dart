import 'package:flutter/material.dart';
import 'capture/capture_screen.dart';
import 'converter/converter_screen.dart';
import 'trimmer/trimmer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  final _screens = const [
    CaptureScreen(),   // Track A: Overlay Recording
    ConverterScreen(), // Track B: File → MIDI
    TrimmerScreen(),   // Legacy: File → WAV
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic),
            selectedIcon: Icon(Icons.mic_rounded),
            label: '녹음→MIDI',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open),
            selectedIcon: Icon(Icons.folder),
            label: '파일→MIDI',
          ),
          NavigationDestination(
            icon: Icon(Icons.content_cut),
            selectedIcon: Icon(Icons.content_cut_rounded),
            label: '트림',
          ),
        ],
      ),
    );
  }
}
