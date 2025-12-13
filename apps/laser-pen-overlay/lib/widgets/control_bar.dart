import 'package:flutter/material.dart';

enum PenColor { white, yellow, black }

class ControlBar extends StatelessWidget {
  final PenColor currentColor;
  final VoidCallback onColorChange;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onExit;
  final bool canUndo;
  final bool canRedo;

  const ControlBar({
    super.key,
    required this.currentColor,
    required this.onColorChange,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onExit,
    this.canUndo = false,
    this.canRedo = false,
  });

  Color get _displayColor {
    switch (currentColor) {
      case PenColor.white:
        return Colors.white;
      case PenColor.yellow:
        return Colors.yellow;
      case PenColor.black:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color button with swipe
          GestureDetector(
            onHorizontalDragEnd: (_) => onColorChange(),
            onTap: onColorChange,
            child: _ControlButton(
              icon: Icons.palette,
              color: _displayColor,
              size: 56,
              tooltip: '색상 (스와이프)',
            ),
          ),
          const SizedBox(width: 8),
          // Undo
          _ControlButton(
            icon: Icons.undo,
            onTap: canUndo ? onUndo : null,
            enabled: canUndo,
            tooltip: '되돌리기',
          ),
          const SizedBox(width: 8),
          // Redo
          _ControlButton(
            icon: Icons.redo,
            onTap: canRedo ? onRedo : null,
            enabled: canRedo,
            tooltip: '다시 실행',
          ),
          const SizedBox(width: 8),
          // Clear
          _ControlButton(
            icon: Icons.delete_outline,
            onTap: onClear,
            tooltip: '전체 지우기',
          ),
          const SizedBox(width: 8),
          // Exit
          _ControlButton(
            icon: Icons.close,
            onTap: onExit,
            color: Colors.redAccent,
            tooltip: '종료',
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final bool enabled;
  final String? tooltip;

  const _ControlButton({
    required this.icon,
    this.onTap,
    this.color,
    this.size = 48,
    this.enabled = true,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled 
                ? (color ?? Colors.white) 
                : Colors.grey,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: enabled 
              ? (color ?? Colors.white) 
              : Colors.grey,
            size: size * 0.5,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
