import 'package:flutter/material.dart';
import '../widgets/tree_view.dart';
import '../core/state.dart' as fsm;

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayWidget());
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  int _stage = 0;

  void _next() {
    setState(() {
      _stage = (_stage + 1) % 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 24),
            child: TreeView(active: _stage, onTap: _next),
          ),
        ),
      ),
    );
  }
}
