import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FirebaseMessaging.instance);
});

class NotificationService {
  final FirebaseMessaging _firebaseMessaging;

  NotificationService(this._firebaseMessaging);

  Future<void> initialize() async {
    try {
      // Request permission for push notifications (Android 13+ & iOS)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Retrieve token
        await _firebaseMessaging.getToken();
      }

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Foreground presentation
      });

      // Handle background notification clicks
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationNavigation(message.data);
      });
    } catch (_) {
      // Notification initialization failure is non-fatal
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      // Navigation route
    }
  }
}
