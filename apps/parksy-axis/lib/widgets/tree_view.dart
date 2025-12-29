import 'package:flutter/material.dart';
import '../models/theme.dart';

class TreeView extends StatelessWidget {
  final int active;
  final VoidCallback onTap;
  final ValueChanged<int>? onStageTap;
  final String rootName;
  final List<String> stages;
  
  // v4.0 스타일링
  final AxisTheme theme;
  final AxisFont font;
  final double bgOpacity;
  final double strokeWidth;

  const TreeView({
    super.key,
    required this.active,
    required this.onTap,
    this.onStageTap,
    this.rootName = '[Idea]',
    this.stages = const ['Capture', 'Note', 'Build', 'Test', 'Publish'],
    this.theme = const AxisTheme(
      id: 'amber',
      name: 'Amber',
      accent: Color(0xFFFFB300),
      bg: Color(0xFF0D0D0D),
      text: Color(0xFFBDBDBD),
      dim: Color(0xFF757575),
    ),
    this.font = const AxisFont(
      id: 'mono',
      name: 'Mono',
      family: 'monospace',
    ),
    this.bgOpacity = 0.9,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        // 반응형 스케일 계산
        final scale = _calcScale(box);
        final fontSize = 14.0 * scale;
        final padH = 12.0 * scale;
        final padV = 8.0 * scale;
        final radius = 10.0 * scale;
        final rowPad = 6.0 * scale;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: padH,
              vertical: padV,
            ),
            decoration: BoxDecoration(
              color: theme.bg.withOpacity(bgOpacity),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: theme.accent.withOpacity(0.3),
                width: strokeWidth,
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
                _buildLabel(rootName, false, fontSize),
                SizedBox(height: rowPad / 2),
                ...List.generate(stages.length, (i) {
                  final isLast = i == stages.length - 1;
                  final prefix = isLast ? '└─' : '├─';
                  return _buildRow(
                    prefix,
                    stages[i],
                    i == active,
                    i,
                    fontSize,
                    rowPad,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  double _calcScale(BoxConstraints box) {
    // 기준: 260x300, 스케일 1.0
    final wScale = box.maxWidth / 260;
    final hScale = box.maxHeight / 300;
    return (wScale + hScale) / 2;
  }

  Widget _buildLabel(String t, bool on, double size) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size * 0.2),
      child: Text(
        t,
        style: TextStyle(
          fontFamily: font.family,
          fontSize: size,
          color: on ? theme.accent : theme.text,
          fontWeight: on ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRow(
    String pre,
    String txt,
    bool on,
    int idx,
    double size,
    double pad,
  ) {
    final indicator = on ? ' ◀●' : '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onStageTap != null ? () => onStageTap!(idx) : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: pad,
          horizontal: size * 0.25,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$pre ',
              style: TextStyle(
                fontFamily: font.family,
                fontSize: size,
                color: theme.dim,
              ),
            ),
            Flexible(
              child: Text(
                txt,
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: size,
                  color: on ? theme.accent : theme.dim,
                  fontWeight: on ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (on)
              Text(
                indicator,
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: size,
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
