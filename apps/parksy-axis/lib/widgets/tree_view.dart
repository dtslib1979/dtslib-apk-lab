/// Parksy Axis v9.0.0 - TreeView 위젯
/// 애니메이션 + 그라데이션 + 성능 최적화

import 'package:flutter/material.dart';
import '../models/theme.dart';
import '../core/constants.dart';

/// 트리뷰 위젯 - 반응형 스케일링 + 애니메이션
class TreeView extends StatefulWidget {
  final int active;
  final VoidCallback onTap;
  final ValueChanged<int>? onJump;
  final String root;
  final List<String> items;
  final AxisTheme theme;
  final AxisFont font;
  final double opacity;
  final double stroke;
  final bool enableAnimation;

  const TreeView({
    super.key,
    required this.active,
    required this.onTap,
    this.onJump,
    this.root = DefaultStages.rootName,
    this.items = DefaultStages.stages,
    required this.theme,
    required this.font,
    this.opacity = UIDefaults.bgOpacity,
    this.stroke = UIDefaults.strokeWidth,
    this.enableAnimation = true,
  });

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  int _lastActive = 0;

  @override
  void initState() {
    super.initState();
    _lastActive = widget.active;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.enableAnimation) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != _lastActive) {
      _lastActive = widget.active;
      if (widget.enableAnimation) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final s = _scale(box);
        final fs = UIDefaults.fontSizeMedium * s;
        final px = 12.0 * s;
        final py = 8.0 * s;
        final r = UIDefaults.borderRadius * s;
        final gap = 6.0 * s;

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.theme.bg.withOpacity(widget.opacity),
                  widget.theme.bgSecondary.withOpacity(widget.opacity * 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(r),
              border: Border.all(
                color: widget.theme.accent.withOpacity(0.4),
                width: widget.stroke,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.theme.glow,
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RootLabel(
                  text: widget.root,
                  fontSize: fs,
                  theme: widget.theme,
                  font: widget.font,
                ),
                SizedBox(height: gap / 2),
                ...List.generate(widget.items.length, (i) {
                  final isLast = i == widget.items.length - 1;
                  final isActive = i == widget.active;
                  return _StageRow(
                    prefix: isLast ? '└─' : '├─',
                    text: widget.items[i],
                    isActive: isActive,
                    index: i,
                    fontSize: fs,
                    gap: gap,
                    theme: widget.theme,
                    font: widget.font,
                    onJump: widget.onJump,
                    pulseAnimation: isActive ? _pulseAnimation : null,
                    enableAnimation: widget.enableAnimation,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  double _scale(BoxConstraints c) =>
      (c.maxWidth / OverlayDefaults.width + c.maxHeight / OverlayDefaults.height) / 2;
}

/// 루트 레이블 위젯
class _RootLabel extends StatelessWidget {
  final String text;
  final double fontSize;
  final AxisTheme theme;
  final AxisFont font;

  const _RootLabel({
    required this.text,
    required this.fontSize,
    required this.theme,
    required this.font,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: fontSize * 0.2),
      child: ShaderMask(
        shaderCallback: (bounds) => theme.accentGradient.createShader(bounds),
        child: Text(
          text,
          style: font.style(
            size: fontSize * 1.1,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 스테이지 행 위젯
class _StageRow extends StatelessWidget {
  final String prefix;
  final String text;
  final bool isActive;
  final int index;
  final double fontSize;
  final double gap;
  final AxisTheme theme;
  final AxisFont font;
  final ValueChanged<int>? onJump;
  final Animation<double>? pulseAnimation;
  final bool enableAnimation;

  const _StageRow({
    required this.prefix,
    required this.text,
    required this.isActive,
    required this.index,
    required this.fontSize,
    required this.gap,
    required this.theme,
    required this.font,
    this.onJump,
    this.pulseAnimation,
    this.enableAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget row = Container(
      padding: EdgeInsets.symmetric(vertical: gap, horizontal: fontSize * 0.25),
      decoration: isActive
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.accent.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$prefix ',
            style: font.style(
              size: fontSize,
              color: theme.dim,
            ),
          ),
          Flexible(
            child: Text(
              text,
              style: font.style(
                size: fontSize,
                color: isActive ? theme.accent : theme.dim,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 4),
            _ActiveIndicator(
              fontSize: fontSize,
              theme: theme,
              font: font,
              pulseAnimation: pulseAnimation,
              enableAnimation: enableAnimation,
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onJump != null ? () => onJump!(index) : null,
      child: row,
    );
  }
}

/// 활성 인디케이터 위젯
class _ActiveIndicator extends StatelessWidget {
  final double fontSize;
  final AxisTheme theme;
  final AxisFont font;
  final Animation<double>? pulseAnimation;
  final bool enableAnimation;

  const _ActiveIndicator({
    required this.fontSize,
    required this.theme,
    required this.font,
    this.pulseAnimation,
    this.enableAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = Text(
      '◀●',
      style: font.style(
        size: fontSize,
        color: theme.accent,
        fontWeight: FontWeight.bold,
      ),
    );

    if (enableAnimation && pulseAnimation != null) {
      return AnimatedBuilder(
        animation: pulseAnimation!,
        builder: (_, child) => Transform.scale(
          scale: pulseAnimation!.value,
          child: child,
        ),
        child: indicator,
      );
    }

    return indicator;
  }
}
