import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parksy_audio_tools/widgets/preset_selector.dart';

void main() {
  group('PresetSelector', () {
    testWidgets('renders all presets', (tester) async {
      int? selectedValue;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresetSelector(
              presets: const [60, 120, 180],
              selectedValue: 60,
              onChanged: (v) => selectedValue = v,
            ),
          ),
        ),
      );

      // Should display 3 choice chips
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      
      // Should show formatted labels
      expect(find.text('1분'), findsOneWidget);
      expect(find.text('2분'), findsOneWidget);
      expect(find.text('3분'), findsOneWidget);
    });

    testWidgets('calls onChanged when chip selected', (tester) async {
      int? selectedValue;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresetSelector(
              presets: const [60, 120, 180],
              selectedValue: 60,
              onChanged: (v) => selectedValue = v,
            ),
          ),
        ),
      );

      // Tap on 2분 chip
      await tester.tap(find.text('2분'));
      await tester.pump();

      expect(selectedValue, 120);
    });

    testWidgets('shows selected state correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresetSelector(
              presets: const [60, 120, 180],
              selectedValue: 120,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Find all ChoiceChips
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final chipList = chips.toList();

      // Second chip (120 seconds = 2분) should be selected
      expect(chipList[0].selected, false);
      expect(chipList[1].selected, true);
      expect(chipList[2].selected, false);
    });
  });
}
