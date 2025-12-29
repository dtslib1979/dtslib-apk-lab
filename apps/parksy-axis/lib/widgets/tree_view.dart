import 'package:flutter/material.dart';

class TreeView extends StatelessWidget {
  final int active;
  final VoidCallback onTap;
  final ValueChanged<int>? onStageTap;
  final String rootName;
  final List<String> stages;

  const TreeView({
    super.key,
    required this.active,
    required this.onTap,
    this.onStageTap,
    this.rootName = '[Idea]',
    this.stages = const ['Capture', 'Note', 'Build', 'Test', 'Publish'],
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(rootName, false),
            const SizedBox(height: 4),
            ...List.generate(stages.length, (i) {
              final isActive = i == active;
              final prefix = i == stages.length - 1 ? '└─' : '├─';
              return _row(prefix, stages[i], isActive, i);
            }),
          ],
        ),
      ),
    );
  }

  Widget _label(String t, bool on) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        t,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          color: on ? Colors.amber : Colors.grey[400],
          fontWeight: on ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _row(String pre, String txt, bool on, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onStageTap != null ? () => onStageTap!(index) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          '$pre $txt${on ? " ◀●" : ""}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            color: on ? Colors.amber : Colors.grey[500],
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
