import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/core/services/notification_service.dart';

void main() {
  group('ReminderSettings Tests', () {
    test('formats PM time correctly', () {
      const settings = ReminderSettings(isEnabled: true, hour: 19, minute: 0);
      expect(settings.formattedTime, '7:00 PM');
    });

    test('formats AM time correctly', () {
      const settings = ReminderSettings(isEnabled: true, hour: 8, minute: 30);
      expect(settings.formattedTime, '8:30 AM');
    });

    test('formats midnight (12:00 AM) correctly', () {
      const settings = ReminderSettings(isEnabled: true, hour: 0, minute: 0);
      expect(settings.formattedTime, '12:00 AM');
    });

    test('formats noon (12:00 PM) correctly', () {
      const settings = ReminderSettings(isEnabled: true, hour: 12, minute: 15);
      expect(settings.formattedTime, '12:15 PM');
    });
  });
}
