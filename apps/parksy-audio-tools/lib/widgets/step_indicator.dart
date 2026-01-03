import 'package:flutter/material.dart';

/// Reusable step indicator widget for processing pipelines
/// Shows dots with labels and connecting lines
class StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int currentStep; // 0 = idle, 1+ = active step

  const StepIndicator({
    super.key,
    required this.steps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepDot(
            step: i + 1,
            label: steps[i],
            isActive: currentStep >= i + 1,
            isCurrent: currentStep == i + 1,
          ),
          if (i < steps.length - 1)
            _StepLine(isActive: currentStep > i + 1),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final String label;
  final bool isActive;
  final bool isCurrent;

  const _StepDot({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surfaceContainerHighest;
    final onPrimary = theme.colorScheme.onPrimary;
    final onSurface = theme.colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? primary : surface,
            border: isCurrent 
              ? Border.all(color: primary, width: 2)
              : null,
          ),
          child: Center(
            child: isActive
              ? Icon(Icons.check, size: 16, color: onPrimary)
              : Text(
                  '$step',
                  style: TextStyle(fontSize: 12, color: onSurface),
                ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isActive ? primary : onSurface,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool isActive;

  const _StepLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive 
        ? theme.colorScheme.primary 
        : theme.colorScheme.surfaceContainerHighest,
    );
  }
}
