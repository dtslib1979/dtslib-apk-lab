import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/widgets/step_indicator.dart';

void main() {
  group('StepIndicator', () {
    testWidgets('renders correct number of steps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StepIndicator(
              steps: ['A', 'B', 'C'],
              currentStep: 0,
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('shows step numbers when inactive', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StepIndicator(
              steps: ['First', 'Second'],
              currentStep: 0,
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows check icon for completed steps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StepIndicator(
              steps: ['Done', 'Current', 'Next'],
              currentStep: 2,
            ),
          ),
        ),
      );

      // Step 1 should show check (completed)
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('handles two steps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StepIndicator(
              steps: ['MP3', 'MIDI'],
              currentStep: 1,
            ),
          ),
        ),
      );

      expect(find.text('MP3'), findsOneWidget);
      expect(find.text('MIDI'), findsOneWidget);
    });

    testWidgets('handles single step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StepIndicator(
              steps: ['Only'],
              currentStep: 1,
            ),
          ),
        ),
      );

      expect(find.text('Only'), findsOneWidget);
    });
  });
}
