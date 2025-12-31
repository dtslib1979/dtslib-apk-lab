import 'package:flutter/material.dart';
import '../models/subtitle.dart';
import '../config/app_config.dart';

class DualSubtitle extends StatelessWidget {
  final Subtitle subtitle;
  final bool compact;
  final VoidCallback? onTap;

  const DualSubtitle({
    super.key,
    required this.subtitle,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (subtitle.isEmpty) {
      return _buildPlaceholder();
    }

    final scale = AppConfig.subtitleSize;
    final baseFontSize = compact ? 14.0 : 18.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 20,
          vertical: compact ? 8 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Korean
            _SubtitleLine(
              flag: '🇰🇷',
              text: subtitle.korean,
              fontSize: baseFontSize * scale,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            SizedBox(height: compact ? 6 : 10),
            // English
            _SubtitleLine(
              flag: '🇺🇸',
              text: subtitle.english,
              fontSize: (baseFontSize - 2) * scale,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '음성을 기다리는 중...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtitleLine extends StatelessWidget {
  final String flag;
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  const _SubtitleLine({
    required this.flag,
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          flag,
          style: TextStyle(fontSize: fontSize - 2),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.isEmpty ? '...' : text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: text.isEmpty ? color.withOpacity(0.3) : color,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
