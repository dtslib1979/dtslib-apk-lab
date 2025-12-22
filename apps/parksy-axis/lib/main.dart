import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AxisApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  int _stage = 0;

  void _next() {
    setState(() => _stage = (_stage + 1) % 5);
  }

  @override
  Widget build(BuildContext context) {
    const stages = ['Capture', 'Note', 'Build', 'Test', 'Publish'];
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _next,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '[Idea]',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                ...List.generate(5, (i) {
                  final on = i == _stage;
                  final pre = i == 4 ? '└─' : '├─';
                  final mark = on ? ' ◀ ●' : '';
                  return Text(
                    '$pre ${stages[i]}$mark',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: on ? Colors.amber : Colors.grey,
                      fontWeight: on ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
