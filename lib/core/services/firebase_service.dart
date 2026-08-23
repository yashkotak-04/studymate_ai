import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appFirebaseServiceProvider = Provider<AppFirebaseService>((ref) => AppFirebaseService());
final firebaseServiceProvider = appFirebaseServiceProvider;

class AppFirebaseService {
  FirebaseAnalytics? _analytics;
  FirebaseRemoteConfig? _remoteConfig;

  FirebaseAnalytics? get analytics => _analytics;
  FirebaseRemoteConfig? get remoteConfig => _remoteConfig;

  Future<void> initialize() async {
    // 1. App Check
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    } catch (e) {
      debugPrint('Firebase App Check initialization info: $e');
    }

    // 2. Crashlytics
    try {
      if (!kIsWeb) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
    } catch (e) {
      debugPrint('Crashlytics initialization info: $e');
    }

    // 3. Analytics
    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics?.logAppOpen();
    } catch (e) {
      debugPrint('Analytics initialization info: $e');
    }

    // 4. Remote Config
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      await _remoteConfig?.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval: kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 1),
      ));
      
      await _remoteConfig?.setDefaults(const {
        'ai_enabled': true,
        'ai_model_name': 'gemini-2.5-flash',
        'max_mcq_count': 20,
        'max_summary_input': 10000,
        'max_pdf_size_mb': 10,
        'max_chat_context_messages': 10,
      });

      await _remoteConfig?.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config initialization info: $e');
    }
  }

  // Remote Config Getters with safe fallbacks
  String get aiModelName {
    try {
      final name = _remoteConfig?.getString('ai_model_name');
      if (name != null && name.isNotEmpty && !name.contains('1.5')) {
        return name;
      }
    } catch (_) {}
    return 'gemini-2.5-flash';
  }

  bool get aiEnabled {
    try {
      return _remoteConfig?.getBool('ai_enabled') ?? true;
    } catch (_) {
      return true;
    }
  }

  int get maxMcqCount {
    try {
      final val = _remoteConfig?.getInt('max_mcq_count') ?? 20;
      return val > 0 ? val : 20;
    } catch (_) {
      return 20;
    }
  }

  int get maxSummaryInput {
    try {
      final val = _remoteConfig?.getInt('max_summary_input') ?? 10000;
      return val > 0 ? val : 10000;
    } catch (_) {
      return 10000;
    }
  }

  int get maxPdfSizeMb {
    try {
      final val = _remoteConfig?.getInt('max_pdf_size_mb') ?? 10;
      return val > 0 ? val : 10;
    } catch (_) {
      return 10;
    }
  }

  int get maxChatContextMessages {
    try {
      final val = _remoteConfig?.getInt('max_chat_context_messages') ?? 10;
      return val > 0 ? val : 10;
    } catch (_) {
      return 10;
    }
  }

  // Non-sensitive privacy-compliant Analytics logging
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics log error: $e');
    }
  }

  Future<void> logSignupCompleted(String method) =>
      logEvent('signup_completed', {'method': method});

  Future<void> logOnboardingCompleted() =>
      logEvent('onboarding_completed');

  Future<void> logChatStarted(String mode) =>
      logEvent('chat_started', {'mode': mode});

  Future<void> logQuizGenerated(String subject, int count, bool isMock) =>
      logEvent('quiz_generated', {'subject': subject, 'count': count, 'is_mock': isMock});

  Future<void> logQuizCompleted(String subject, int score, int total, bool isMock) =>
      logEvent('quiz_completed', {'subject': subject, 'score': score, 'total': total, 'is_mock': isMock});

  Future<void> logSummaryGenerated(String source) =>
      logEvent('summary_generated', {'source_type': source});

  Future<void> logStudyPlanGenerated() =>
      logEvent('study_plan_generated');

  Future<void> logRecommendationOpened(String actionType) =>
      logEvent('recommendation_opened', {'action_type': actionType});
}
