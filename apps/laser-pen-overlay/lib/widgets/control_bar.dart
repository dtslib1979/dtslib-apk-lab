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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color (swipe)
          GestureDetector(
            onHorizontalDragEnd: (_) => onColorChange(),
            onTap: onColorChange,
            child: _Btn(
              icon: Icons.palette,
              color: _displayColor,
              size: 56,
            ),
          ),
          const SizedBox(width: 8),
          // Undo
          _Btn(
            icon: Icons.undo,
            onTap: canUndo ? onUndo : null,
            enabled: canUndo,
          ),
          const SizedBox(width: 8),
          // Redo
          _Btn(
            icon: Icons.redo,
            onTap: canRedo ? onRedo : null,
            enabled: canRedo,
          ),
          const SizedBox(width: 8),
          // Clear
          _Btn(
            icon: Icons.delete_outline,
            onTap: onClear,
          ),
          const SizedBox(width: 8),
          // Exit
          _Btn(
            icon: Icons.close,
            onTap: onExit,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final bool enabled;

  const _Btn({
    required this.icon,
    this.onTap,
    this.color,
    this.size = 48,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? (color ?? Colors.white) : Colors.grey;
    
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c, width: 2),
        ),
        child: Icon(icon, color: c, size: size * 0.5),
      ),
    );
  }
}
