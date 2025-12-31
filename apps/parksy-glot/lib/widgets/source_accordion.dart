import 'package:flutter/material.dart';
import '../models/subtitle.dart';
import '../models/language.dart';

class SourceAccordion extends StatefulWidget {
  final Subtitle subtitle;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const SourceAccordion({
    super.key,
    required this.subtitle,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  @override
  State<SourceAccordion> createState() => _SourceAccordionState();
}

class _SourceAccordionState extends State<SourceAccordion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  late Animation<double> _iconRotation;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    _iconRotation = _controller.drive(
      Tween<double>(begin: 0, end: 0.5).chain(CurveTween(curve: Curves.easeInOut)),
    );

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subtitle.isEmpty || widget.subtitle.original.isEmpty) {
      return const SizedBox.shrink();
    }

    final lang = widget.subtitle.detectedLanguage;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          GestureDetector(
            onTap: _handleTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Text(
                    lang.flag,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '원문 (${lang.displayName})',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  RotationTransition(
                    turns: _iconRotation,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Align(
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.subtitle.original,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
