import 'package:flutter/material.dart';

class TreeView extends StatelessWidget {
  final int active;
  final VoidCallback onTap;
  final String rootName;
  final List<String> stages;

  const TreeView({
    super.key,
    required this.active,
    required this.onTap,
    this.rootName = '[Idea]',
    this.stages = const ['Capture', 'Note', 'Build', 'Test', 'Publish'],
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            _label(rootName, false),
            ...List.generate(stages.length, (i) {
              final isActive = i == active;
              final prefix = i == stages.length - 1 ? '└─' : '├─';
              return _row(prefix, stages[i], isActive);
            }),
          ],
        ),
      ),
    );
  }

  Widget _label(String t, bool on) {
    return Text(
      t,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: on ? Colors.amber : Colors.grey,
        fontWeight: on ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _row(String pre, String txt, bool on) {
    final mark = on ? '◀ ● ' : '    ';
    return Text(
      '$pre $txt $mark',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: on ? Colors.amber : Colors.grey,
        fontWeight: on ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
