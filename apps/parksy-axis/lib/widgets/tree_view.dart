import 'package:flutter/material.dart';

class TreeView extends StatelessWidget {
  final int active;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap; // 더블탭 → 크기 변경
  final ValueChanged<int>? onStageTap; // 개별 스테이지 탭 → 해당 단계로 점프
  final String rootName;
  final List<String> stages;
  final String? sizeLabel; // S/M/L 표시

  const TreeView({
    super.key,
    required this.active,
    required this.onTap,
    this.onDoubleTap,
    this.onStageTap,
    this.rootName = '[Idea]',
    this.stages = const ['Capture', 'Note', 'Build', 'Test', 'Publish'],
    this.sizeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
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
            // 루트 + 크기 표시
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _label(rootName, false),
                if (sizeLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '[$sizeLabel]',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
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

  Widget _row(String pre, String txt, bool on, int index) {
    final mark = on ? ' ◀●' : '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onStageTap != null ? () => onStageTap!(index) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '$pre $txt$mark',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: on ? Colors.amber : Colors.grey.shade500,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
