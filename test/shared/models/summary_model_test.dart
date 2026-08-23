import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/shared/models/summary_model.dart';

void main() {
  group('GeneratedSummary Model Tests', () {
    test('fromJson correctly parses 5 required sections', () {
      final json = {
        'quickSummary': 'Core premise of Operating Systems.',
        'importantPoints': ['Point 1', 'Point 2'],
        'keyTerms': ['Kernel', 'Process'],
        'examFocus': ['Deadlock Conditions', 'Banker Algorithm'],
        'revisionQuestions': ['What is a race condition?'],
      };

      final summary = GeneratedSummary.fromJson(json);

      expect(summary.quickSummary, equals('Core premise of Operating Systems.'));
      expect(summary.importantPoints.length, equals(2));
      expect(summary.keyTerms.length, equals(2));
      expect(summary.examFocus.length, equals(2));
      expect(summary.revisionQuestions.length, equals(1));
    });

    test('toJson encodes all 5 sections properly', () {
      final summary = GeneratedSummary(
        quickSummary: 'Brief overview',
        importantPoints: ['Point A'],
        keyTerms: ['Term A'],
        examFocus: ['Focus A'],
        revisionQuestions: ['Question A'],
      );

      final json = summary.toJson();
      expect(json['quickSummary'], equals('Brief overview'));
      expect(json['examFocus'], equals(['Focus A']));
    });
  });
}
