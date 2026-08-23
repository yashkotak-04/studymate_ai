import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:studymate_ai/shared/widgets/custom_button.dart';

void main() {
  Widget createWidgetUnderTest(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('CustomButton Tests', () {
    testWidgets('renders text correctly', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(const CustomButton(text: 'Click Me')),
      );

      expect(find.text('Click Me'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          CustomButton(text: 'Tap', onPressed: () => tapped = true),
        ),
      );

      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const CustomButton(text: 'With Icon', icon: LucideIcons.sparkles),
        ),
      );

      expect(find.byIcon(LucideIcons.sparkles), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const CustomButton(text: 'Disabled', onPressed: null),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.enabled, isFalse);
    });
  });
}
