import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studymate_ai/app/theme/app_theme.dart';
import 'package:studymate_ai/features/auth/presentation/login_screen.dart';
import 'package:studymate_ai/features/practice/presentation/mcq_setup_screen.dart';
import 'package:studymate_ai/features/practice/presentation/quiz_screen.dart';
import 'package:studymate_ai/features/recommendations/presentation/recommendations_screen.dart';
import 'package:studymate_ai/shared/models/quiz_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('StudyMate AI End-to-End Integration Flows', () {
    testWidgets(
      '1. Launch Smoke Flow: Renders Login screen with active controls',
      (tester) async {
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

        expect(find.text('StudyMate AI'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Create an account'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Quiz Flow: Answers questions, validates selection state and navigation',
      (tester) async {
        final mockQuestions = [
          QuizQuestion(
            question: 'What is a Semaphore in OS?',
            options: [
              'A synchronization tool',
              'A scheduling algorithm',
              'A memory unit',
              'A compiler tool',
            ],
            correctIndex: 0,
            explanation: 'Semaphores are synchronization tools.',
          ),
          QuizQuestion(
            question: 'What is ACID in Database Management?',
            options: [
              'A chemical compound',
              'A set of transaction properties',
              'A routing algorithm',
              'A network layer',
            ],
            correctIndex: 1,
            explanation:
                'ACID guarantees database transactions are processed reliably.',
          ),
        ];

        final mockSession = QuizSession(
          id: 'test_session_1',
          userId: 'test_user',
          subjectId: 'os',
          topic: 'Processes',
          difficulty: 'Medium',
          totalQuestions: mockQuestions.length,
          score: 0,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(minutes: 5)),
          questions: mockQuestions,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [currentQuizProvider.overrideWith((ref) => mockSession)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const QuizScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('What is a Semaphore in OS?'), findsOneWidget);
        expect(find.text('A synchronization tool'), findsOneWidget);

        // Tap first option
        await tester.tap(find.text('A synchronization tool'));
        await tester.pumpAndSettle();

        // Tap Next Question button
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        expect(
          find.text('What is ACID in Database Management?'),
          findsOneWidget,
        );
        expect(find.text('Submit Quiz'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Recommendations Flow: Renders AI diagnostic badges and actionable cards',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const RecommendationsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('AI Recommendations'), findsOneWidget);
        expect(find.text('Diagnostic Recommendations'), findsOneWidget);
        expect(find.text('Actionable Study Tips'), findsOneWidget);
      },
    );
  });
}
