import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/features/progress/presentation/progress_screen.dart';

void main() {
  group('DateRangeWindow Tests', () {
    final fixedNow = DateTime(2026, 8, 23, 12, 0, 0);

    test(
      'week filter includes last 7 days and strictly excludes future dates',
      () {
        final window = DateRangeWindow.forFilter(TimeFilter.week, fixedNow);

        final today = DateTime(2026, 8, 23, 10, 0, 0);
        final fiveDaysAgo = DateTime(2026, 8, 18, 12, 0, 0);
        final eightDaysAgo = DateTime(2026, 8, 15, 12, 0, 0);
        final tomorrow = DateTime(2026, 8, 24, 12, 0, 0);

        expect(window.contains(today), isTrue);
        expect(window.contains(fiveDaysAgo), isTrue);
        expect(window.contains(eightDaysAgo), isFalse);
        expect(window.contains(tomorrow), isFalse);
      },
    );

    test(
      'month filter includes last 30 days and strictly excludes future dates',
      () {
        final window = DateRangeWindow.forFilter(TimeFilter.month, fixedNow);

        final today = DateTime(2026, 8, 23, 10, 0, 0);
        final twentyDaysAgo = DateTime(2026, 8, 3, 12, 0, 0);
        final thirtyFiveDaysAgo = DateTime(2026, 7, 15, 12, 0, 0);
        final tomorrow = DateTime(2026, 8, 24, 12, 0, 0);

        expect(window.contains(today), isTrue);
        expect(window.contains(twentyDaysAgo), isTrue);
        expect(window.contains(thirtyFiveDaysAgo), isFalse);
        expect(window.contains(tomorrow), isFalse);
      },
    );

    test('allTime filter excludes future dates', () {
      final window = DateRangeWindow.forFilter(TimeFilter.allTime, fixedNow);

      final past = DateTime(2023, 1, 1);
      final today = DateTime(2026, 8, 23, 10, 0, 0);
      final future = DateTime(2026, 8, 25);

      expect(window.contains(past), isTrue);
      expect(window.contains(today), isTrue);
      expect(window.contains(future), isFalse);
    });
  });
}
