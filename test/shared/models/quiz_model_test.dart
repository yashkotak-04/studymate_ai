import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/shared/models/quiz_model.dart';

void main() {
  group('QuizQuestion Model Tests', () {
    test('isValid returns true for valid question with 4 options', () {
      final q = QuizQuestion(
        question: 'What is a Semaphore?',
        options: ['Mutex', 'Integer Variable', 'Process', 'Thread'],
        correctIndex: 1,
        explanation: 'A semaphore is an integer variable used for synchronization.',
      );

      expect(q.isValid, isTrue);
      expect(q.wasCorrect, isFalse);
    });

    test('isValid returns false for question with fewer than 4 options', () {
      final q = QuizQuestion(
        question: 'What is a Semaphore?',
        options: ['Option 1', 'Option 2'],
        correctIndex: 0,
        explanation: 'Explanation',
      );

      expect(q.isValid, isFalse);
    });

    test('wasCorrect returns true when selectedIndex matches correctIndex', () {
      final q = QuizQuestion(
        question: 'What is a Semaphore?',
        options: ['Option 1', 'Option 2', 'Option 3', 'Option 4'],
        correctIndex: 2,
        selectedIndex: 2,
        explanation: 'Explanation',
      );

      expect(q.wasCorrect, isTrue);
    });
  });

  group('QuizSession Model Tests', () {
    test('Calculates accuracy and duration correctly', () {
      final start = DateTime(2026, 1, 1, 10, 0);
      final end = DateTime(2026, 1, 1, 10, 15);

      final session = QuizSession(
        id: 'quiz_123',
        userId: 'user_1',
        subjectId: 'os',
        topic: 'Deadlocks',
        difficulty: 'Medium',
        totalQuestions: 10,
        score: 8,
        isCompleted: true,
        startTime: start,
        endTime: end,
        questions: [],
      );

      expect(session.accuracy, equals(80.0));
      expect(session.durationMinutes, equals(15));
      expect(session.isMockTest, isFalse);
    });
  });
}
