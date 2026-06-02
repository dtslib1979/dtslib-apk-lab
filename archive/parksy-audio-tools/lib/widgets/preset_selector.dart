import 'package:flutter/material.dart';

class PresetSelector extends StatelessWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const PresetSelector({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBtn(60, '1분'),
        const SizedBox(width: 12),
        _buildBtn(120, '2분'),
        const SizedBox(width: 12),
        _buildBtn(180, '3분'),
      ],
    );
  }

  Widget _buildBtn(int sec, String label) {
    final selected = value == sec;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onChanged(sec) : null,
      selectedColor: Colors.deepPurple,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : null,
      ),
    );
  }
}
