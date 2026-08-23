import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderSettings {
  final bool isEnabled;
  final int hour;
  final int minute;

  const ReminderSettings({
    required this.isEnabled,
    required this.hour,
    required this.minute,
  });

  String get formattedTime {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMin = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMin $period';
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FirebaseMessaging.instance);
});

final reminderSettingsProvider =
    StateNotifierProvider<ReminderNotifier, ReminderSettings>((ref) {
      final service = ref.watch(notificationServiceProvider);
      return ReminderNotifier(service);
    });

class ReminderNotifier extends StateNotifier<ReminderSettings> {
  final NotificationService _service;

  ReminderNotifier(this._service)
    : super(
        ReminderSettings(
          isEnabled: _service.isReminderScheduled,
          hour: _service.reminderHour,
          minute: _service.reminderMinute,
        ),
      );

  Future<bool> updateReminder({
    required bool isEnabled,
    int? hour,
    int? minute,
  }) async {
    final h = hour ?? state.hour;
    final m = minute ?? state.minute;

    if (isEnabled) {
      final granted = await _service.requestNotificationPermission();
      if (!granted) return false;
      await _service.scheduleDailyStudyReminder(h, m);
    } else {
      await _service.cancelDailyStudyReminder();
    }

    state = ReminderSettings(isEnabled: isEnabled, hour: h, minute: m);
    return true;
  }
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const int _studyReminderNotificationId = 1001;
  static const String _prefReminderEnabled = 'study_reminder_enabled';
  static const String _prefReminderHour = 'study_reminder_hour';
  static const String _prefReminderMinute = 'study_reminder_minute';

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

  /// Initialize local notifications, timezones, preferences, and FCM lifecycle.
  Future<void> initialize() async {
    try {
      // 1. Initialize Timezones
      tz.initializeTimeZones();

      // 2. Initialize Local Notifications Plugin
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && _whitelistedRoutes.contains(payload)) {
            _navigationHandler?.call(payload);
          }
        },
      );

      // 3. Load saved reminder schedule
      final prefs = await SharedPreferences.getInstance();
      _isReminderScheduled = prefs.getBool(_prefReminderEnabled) ?? false;
      _reminderHour = prefs.getInt(_prefReminderHour) ?? 19;
      _reminderMinute = prefs.getInt(_prefReminderMinute) ?? 0;

      // 4. Restore schedule if enabled
      if (_isReminderScheduled) {
        await _scheduleLocalZonedNotification(_reminderHour, _reminderMinute);
      }

      // 5. Setup FCM token listeners safely
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode && newToken.length > 8) {
          debugPrint('FCM Token refreshed: ${newToken.substring(0, 6)}***');
        }
      });

      // 6. Handle foreground FCM notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint(
            'Received foreground notification: ${message.notification?.title}',
          );
        }
      });

      // 7. Handle notification navigation
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationNavigation(message.data);
      });

      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationNavigation(initialMessage.data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService initialization diagnostic: $e');
      }
    }
  }

  /// Request permission on-demand when user opts in
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

  /// Saves FCM token securely under the authenticated user document
  Future<void> syncUserToken(String uid) async {
    if (_fcmToken == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Error syncing user FCM token: $e');
    }
  }

  /// Cleans up FCM token on signout
  Future<void> clearUserToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing user FCM token: $e');
    }
  }

  /// Schedules a real repeating local daily study notification
  Future<void> scheduleDailyStudyReminder(int hour, int minute) async {
    _reminderHour = hour;
    _reminderMinute = minute;
    _isReminderScheduled = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReminderEnabled, true);
    await prefs.setInt(_prefReminderHour, hour);
    await prefs.setInt(_prefReminderMinute, minute);

    await _scheduleLocalZonedNotification(hour, minute);

    if (kDebugMode) {
      debugPrint('Daily study reminder scheduled at $hour:$minute');
    }
  }

  /// Cancels the scheduled local reminder
  Future<void> cancelDailyStudyReminder() async {
    _isReminderScheduled = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReminderEnabled, false);

    await _localNotifications.cancel(id: _studyReminderNotificationId);

    if (kDebugMode) {
      debugPrint('Daily study reminder cancelled.');
    }
  }

  Future<void> _scheduleLocalZonedNotification(int hour, int minute) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'studymate_daily_reminder',
        'Daily Study Reminders',
        channelDescription:
            'Reminders to maintain your study streak and complete daily goals.',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.zonedSchedule(
        id: _studyReminderNotificationId,
        title: 'Time for StudyMate AI! 📚',
        body: 'Keep your streak alive. Complete your daily study goal today!',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '/dashboard',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Local notification scheduling diagnostic: $e');
      }
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
