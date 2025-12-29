import 'package:flutter/material.dart';
import '../models/theme.dart';

/// 트리뷰 위젯 - 반응형 스케일링
class TreeView extends StatelessWidget {
  final int active;
  final VoidCallback onTap;
  final ValueChanged<int>? onJump;
  final String root;
  final List<String> items;
  final AxisTheme theme;
  final AxisFont font;
  final double opacity;
  final double stroke;

  const TreeView({
    super.key,
    required this.active,
    required this.onTap,
    this.onJump,
    this.root = '[Idea]',
    this.items = const ['Capture', 'Note', 'Build', 'Test', 'Publish'],
    this.theme = const AxisTheme(
      id: 'amber',
      name: 'Amber',
      accent: Color(0xFFFFB300),
      bg: Color(0xFF0D0D0D),
      text: Color(0xFFBDBDBD),
      dim: Color(0xFF757575),
    ),
    this.font = const AxisFont(id: 'mono', name: 'Mono', family: 'monospace'),
    this.opacity = 0.9,
    this.stroke = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final s = _scale(box);
        final fs = 14.0 * s;
        final px = 12.0 * s;
        final py = 8.0 * s;
        final r = 10.0 * s;
        final gap = 6.0 * s;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
            decoration: BoxDecoration(
              color: theme.bg.withOpacity(opacity),
              borderRadius: BorderRadius.circular(r),
              border: Border.all(
                color: theme.accent.withOpacity(0.3),
                width: stroke,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(root, false, fs),
                SizedBox(height: gap / 2),
                ...List.generate(items.length, (i) {
                  final pre = i == items.length - 1 ? '└─' : '├─';
                  return _row(pre, items[i], i == active, i, fs, gap);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 스케일 계산: (w/260 + h/300) / 2
  double _scale(BoxConstraints c) => (c.maxWidth / 260 + c.maxHeight / 300) / 2;

  Widget _label(String t, bool on, double sz) => Padding(
        padding: EdgeInsets.symmetric(vertical: sz * 0.2),
        child: Text(
          t,
          style: TextStyle(
            fontFamily: font.family,
            fontSize: sz,
            color: on ? theme.accent : theme.text,
            fontWeight: on ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      );

  Widget _row(String pre, String txt, bool on, int i, double sz, double gap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onJump != null ? () => onJump!(i) : null,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: gap, horizontal: sz * 0.25),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$pre ',
              style: TextStyle(
                fontFamily: font.family,
                fontSize: sz,
                color: theme.dim,
              ),
            ),
            Flexible(
              child: Text(
                txt,
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: sz,
                  color: on ? theme.accent : theme.dim,
                  fontWeight: on ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (on)
              Text(
                ' ◀●',
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: sz,
                  color: theme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
