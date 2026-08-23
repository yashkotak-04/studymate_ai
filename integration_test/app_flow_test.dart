import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studymate_ai/app/theme/app_theme.dart';
import 'package:studymate_ai/features/auth/presentation/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('StudyMate AI Integration Smoke Tests', () {
    testWidgets('Renders Login screen on initial launch with active controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify essential login widgets exist and respond
      expect(find.text('StudyMate AI'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Email & Password
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });
  });
}
