import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/shared/models/chat_model.dart';

void main() {
  group('ExplanationMode Tests', () {
    test('ExplanationMode.fromId returns correct enum value', () {
      expect(
        ExplanationMode.fromId('beginner'),
        equals(ExplanationMode.beginner),
      );
      expect(
        ExplanationMode.fromId('Student'),
        equals(ExplanationMode.student),
      );
      expect(ExplanationMode.fromId('exam'), equals(ExplanationMode.exam));
      expect(ExplanationMode.fromId('Viva'), equals(ExplanationMode.viva));
      expect(
        ExplanationMode.fromId('unknown'),
        equals(ExplanationMode.student),
      );
    });

    test('ExplanationMode contains non-empty systemPrompt and label', () {
      for (final mode in ExplanationMode.values) {
        expect(mode.label.isNotEmpty, isTrue);
        expect(mode.systemPrompt.isNotEmpty, isTrue);
      }
    });
  });
}
