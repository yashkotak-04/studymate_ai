import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/shared/widgets/custom_chip.dart';

void main() {
  Widget createWidgetUnderTest(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('CustomChip Tests', () {
    testWidgets('renders label correctly', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(const CustomChip(label: 'OS')),
      );

      expect(find.text('OS'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          CustomChip(label: 'DBMS', onTap: () => tapped = true),
        ),
      );

      await tester.tap(find.text('DBMS'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
