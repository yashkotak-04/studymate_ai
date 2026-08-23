import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/shared/models/recommendation_model.dart';

void main() {
  group('Recommendation Model Tests', () {
    test(
      'fromJson correctly parses personalized recommendation with evidence',
      () {
        final json = {
          'userId': 'user123',
          'subjectId': 'os',
          'subjectName': 'Operating Systems',
          'topic': 'CPU Scheduling',
          'title': 'Strengthen OS Foundation',
          'reason': 'Accuracy is below 70%',
          'evidence': '4 incorrect answers recorded.',
          'actionLabel': 'Start 10-Question Quiz',
          'actionType': 'practice',
          'actionRoute': '/practice',
          'accuracy': 55.0,
          'isPersonalized': true,
          'isCompleted': false,
          'createdAt': '2026-08-23T10:00:00.000Z',
        };

        final rec = Recommendation.fromJson(json, 'rec_123');

        expect(rec.id, 'rec_123');
        expect(rec.subjectId, 'os');
        expect(rec.evidence, '4 incorrect answers recorded.');
        expect(rec.isPersonalized, true);
        expect(rec.accuracy, 55.0);
      },
    );

    test('toJson encodes all recommendation fields properly', () {
      final rec = Recommendation(
        id: 'rec_456',
        userId: 'user456',
        subjectId: 'py',
        subjectName: 'Python Programming',
        topic: 'Recursion',
        title: 'Master Recursion',
        reason: 'Practice needed',
        evidence: '2 mistakes made',
        actionLabel: 'Take Practice',
        actionType: 'practice',
        actionRoute: '/practice',
        accuracy: 60.0,
        isPersonalized: true,
        createdAt: DateTime(2026, 8, 23),
      );

      final map = rec.toJson();
      expect(map['subjectId'], 'py');
      expect(map['evidence'], '2 mistakes made');
      expect(map['isPersonalized'], true);
    });
  });
}
