import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FirebaseMessaging.instance);
});

class NotificationService {
  final FirebaseMessaging _firebaseMessaging;
  String? _fcmToken;
  bool _notificationsEnabled = false;
  int _reminderHour = 19; // 7:00 PM default
  int _reminderMinute = 0;
  bool _isReminderScheduled = false;
  void Function(String route)? _navigationHandler;

  static const _whitelistedRoutes = <String>{
    '/dashboard',
    '/ai-chat',
    '/practice',
    '/planner',
    '/summary',
    '/recommendations',
    '/progress',
    '/profile',
  };

  NotificationService(this._firebaseMessaging);

  String? get fcmToken => _fcmToken;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isReminderScheduled => _isReminderScheduled;
  int get reminderHour => _reminderHour;
  int get reminderMinute => _reminderMinute;

  void setNavigationHandler(void Function(String route) handler) {
    _navigationHandler = handler;
  }

  /// Explicitly request permission when user opts into notifications
  Future<bool> requestNotificationPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final isGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      _notificationsEnabled = isGranted;

      if (isGranted) {
        _fcmToken = await _firebaseMessaging.getToken();
        if (kDebugMode && _fcmToken != null && _fcmToken!.length > 8) {
          debugPrint('FCM Token registered: ${_fcmToken!.substring(0, 6)}***');
        }
      }
      return isGranted;
    } catch (e) {
      if (kDebugMode) debugPrint('Permission request error: $e');
      return false;
    }
  }

  Future<void> scheduleDailyStudyReminder(int hour, int minute) async {
    _reminderHour = hour;
    _reminderMinute = minute;
    _isReminderScheduled = true;
    if (kDebugMode) {
      debugPrint('Daily study reminder scheduled for $hour:$minute');
    }
  }

  Future<void> cancelDailyStudyReminder() async {
    _isReminderScheduled = false;
    if (kDebugMode) {
      debugPrint('Daily study reminder cancelled.');
    }
  }

  Future<void> initialize() async {
    try {
      // 1. Listen to token refresh safely
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode && newToken.length > 8) {
          debugPrint('FCM Token refreshed: ${newToken.substring(0, 6)}***');
        }
      });

      // 2. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!_notificationsEnabled) return;
        if (kDebugMode) {
          debugPrint(
            'Received foreground notification: ${message.notification?.title}',
          );
        }
      });

      // 3. Handle notification clicks from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationNavigation(message.data);
      });

      // 4. Handle notification that launched app from terminated state
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationNavigation(initialMessage.data);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService initialization info: $e');
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route != null && _whitelistedRoutes.contains(route)) {
      _navigationHandler?.call(route);
    } else if (kDebugMode && route != null) {
      debugPrint('Ignored non-whitelisted notification route: $route');
    }
  }
}
