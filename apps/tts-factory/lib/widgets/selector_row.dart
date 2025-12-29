import 'package:flutter/material.dart';

class SelectorRow extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String selected;
  final bool enabled;
  final ValueChanged<String>? onSelected;
  final Color selectedColor;

  const SelectorRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    this.enabled = true,
    this.onSelected,
    this.selectedColor = const Color(0xFF58A6FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.entries.map((e) {
                return ChoiceChip(
                  label: Text(e.value),
                  selected: selected == e.key,
                  onSelected: enabled
                      ? (sel) {
                          if (sel) onSelected?.call(e.key);
                        }
                      : null,
                  selectedColor: selectedColor.withValues(alpha: 0.3),
                  backgroundColor: const Color(0xFF21262D),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
