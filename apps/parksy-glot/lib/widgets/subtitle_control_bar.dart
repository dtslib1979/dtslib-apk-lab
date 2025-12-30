import 'package:flutter/material.dart';

class SubtitleControlBar extends StatelessWidget {
  final bool isCapturing;
  final bool showOriginal;
  final VoidCallback onStartStop;
  final VoidCallback onToggleOriginal;
  final VoidCallback onSettings;
  final VoidCallback? onExit;

  const SubtitleControlBar({
    super.key,
    required this.isCapturing,
    required this.showOriginal,
    required this.onStartStop,
    required this.onToggleOriginal,
    required this.onSettings,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Start/Stop button
          _ControlButton(
            icon: isCapturing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: isCapturing ? Colors.redAccent : const Color(0xFF22C55E),
            size: 52,
            onTap: onStartStop,
            tooltip: isCapturing ? '중지' : '시작',
          ),
          const SizedBox(width: 4),
          // Toggle original
          _ControlButton(
            icon: showOriginal ? Icons.subtitles : Icons.subtitles_outlined,
            color: showOriginal ? const Color(0xFF6366F1) : null,
            onTap: onToggleOriginal,
            tooltip: '원문 표시',
          ),
          const SizedBox(width: 4),
          // Settings
          _ControlButton(
            icon: Icons.tune,
            onTap: onSettings,
            tooltip: '설정',
          ),
          if (onExit != null) ...[
            const SizedBox(width: 4),
            _ControlButton(
              icon: Icons.close,
              color: Colors.redAccent.withOpacity(0.8),
              onTap: onExit!,
              tooltip: '종료',
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final VoidCallback onTap;
  final String? tooltip;

  const _ControlButton({
    required this.icon,
    this.color,
    this.size = 44,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color?.withOpacity(0.2) ?? Colors.white.withOpacity(0.1),
          border: Border.all(
            color: color ?? Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: color ?? Colors.white.withOpacity(0.9),
          size: size * 0.5,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
