import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/core/services/ai_service.dart';

void main() {
  group('AI Exceptions Tests', () {
    test('AiDisabledException returns user-friendly message', () {
      const exception = AiDisabledException();
      expect(
        exception.toString(),
        'AI features are temporarily unavailable. Your saved study content is still accessible.',
      );
    });

    test('AiDisabledException allows custom message', () {
      const exception = AiDisabledException('Custom disabled message');
      expect(exception.toString(), 'Custom disabled message');
    });

    test('AiQuizGenerationException returns clear error message', () {
      const exception = AiQuizGenerationException();
      expect(
        exception.toString(),
        'Could not generate the requested quiz questions. Please try again.',
      );
    });
  });
}
