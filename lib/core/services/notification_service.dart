import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FirebaseMessaging.instance);
});

class NotificationService {
  final FirebaseMessaging _firebaseMessaging;
  String? _fcmToken;
  bool _notificationsEnabled = true;
  void Function(String route)? _navigationHandler;

  NotificationService(this._firebaseMessaging);

  String? get fcmToken => _fcmToken;
  bool get notificationsEnabled => _notificationsEnabled;

  void setNavigationHandler(void Function(String route) handler) {
    _navigationHandler = handler;
  }

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  Future<void> initialize() async {
    try {
      // 1. Request permission for push notifications (Android 13+ & iOS)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _notificationsEnabled = true;
        // Retrieve and track token
        _fcmToken = await _firebaseMessaging.getToken();
        debugPrint('FCM Registration Token: $_fcmToken');
      }

      // 2. Listen to token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
      });

      // 3. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!_notificationsEnabled) return;
        debugPrint(
          'Received foreground notification: ${message.notification?.title}',
        );
      });

      // 4. Handle notification clicks from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationNavigation(message.data);
      });

      // 5. Handle notification that launched app from terminated state
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationNavigation(initialMessage.data);
      }
    } catch (e) {
      debugPrint('NotificationService initialization info: $e');
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      _navigationHandler?.call(route);
    }
  }
}
