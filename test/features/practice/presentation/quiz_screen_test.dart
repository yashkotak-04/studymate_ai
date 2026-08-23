import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studymate_ai/app/theme/app_theme.dart';
import 'package:studymate_ai/features/practice/presentation/mcq_setup_screen.dart';
import 'package:studymate_ai/features/practice/presentation/quiz_screen.dart';
import 'package:studymate_ai/shared/models/quiz_model.dart';

void main() {
  testWidgets('QuizScreen renders question text and options correctly', (
    tester,
  ) async {
    final mockSession = QuizSession(
      id: 'quiz_test_1',
      userId: 'user_1',
      subjectId: 'os',
      topic: 'Process Scheduling',
      difficulty: 'Medium',
      totalQuestions: 2,
      score: 0,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(minutes: 10)),
      questions: [
        QuizQuestion(
          question: 'Which scheduling algorithm is non-preemptive?',
          options: ['FCFS', 'Round Robin', 'SRTF', 'Priority Preemptive'],
          correctIndex: 0,
          explanation: 'First-Come, First-Served is non-preemptive.',
        ),
        QuizQuestion(
          question: 'What is a critical section?',
          options: [
            'Code accessing shared resource',
            'CPU cache',
            'Deadlock state',
            'Thread queue',
          ],
          correctIndex: 0,
          explanation:
              'A critical section is a piece of code that accesses shared memory.',
        ),
      ],
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

    expect(
      find.text('Which scheduling algorithm is non-preemptive?'),
      findsOneWidget,
    );
    expect(find.text('FCFS'), findsOneWidget);
    expect(find.text('Round Robin'), findsOneWidget);
    expect(find.text('Next Question'), findsOneWidget);
  });
}
