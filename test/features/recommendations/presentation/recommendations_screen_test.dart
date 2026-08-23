import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studymate_ai/app/theme/app_theme.dart';
import 'package:studymate_ai/features/recommendations/presentation/recommendations_screen.dart';

import 'package:studymate_ai/shared/models/recommendation_model.dart';

void main() {
  testWidgets(
    'RecommendationsScreen renders AI recommendations header and cards',
    (tester) async {
      final mockRecs = [
        Recommendation(
          id: 'rec_1',
          userId: 'u1',
          subjectId: 'general',
          subjectName: 'AI Tutor',
          topic: 'Concept Clarification',
          title: 'Ask AI Tutor Tricky Viva & Exam Questions',
          reason: 'Stuck on complex definitions?',
          actionLabel: 'Open AI Tutor',
          actionType: 'chat',
          actionRoute: '/chat',
          isPersonalized: false,
          createdAt: DateTime.now(),
        ),
        Recommendation(
          id: 'rec_2',
          userId: 'u1',
          subjectId: 'summary',
          subjectName: 'Smart Notes',
          topic: 'Exam Revision',
          title: 'Generate Exam-Focus Revision Summaries',
          reason: 'Upload notes',
          actionLabel: 'Summarize Document',
          actionType: 'summary',
          actionRoute: '/summary',
          isPersonalized: false,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [recommendationsProvider.overrideWithValue(mockRecs)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RecommendationsScreen(),
          ),
        ),
      );

      expect(find.text('AI Recommendations'), findsOneWidget);
      expect(
        find.text('Ask AI Tutor Tricky Viva & Exam Questions'),
        findsOneWidget,
      );
      expect(
        find.text('Generate Exam-Focus Revision Summaries'),
        findsOneWidget,
      );
    },
  );
}
