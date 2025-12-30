import 'package:flutter/material.dart';
import 'trimmer/trimmer_home.dart';
import 'converter/converter_home.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  static const _pages = [
    TrimmerHome(),
    ConverterHome(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.content_cut),
            label: 'Trimmer',
          ),
          NavigationDestination(
            icon: Icon(Icons.transform),
            label: 'MIDI',
          ),
        ],
      ),
    );
  }
}
