import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Production Firebase configuration for StudyMate AI (studymate-ai-9e018).
/// Generated automatically via FlutterFire CLI.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static bool get isConfigured {
    try {
      final opts = currentPlatform;
      return !opts.apiKey.contains('STUB') && !opts.projectId.contains('stub');
    } catch (_) {
      return false;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-hjrbRwrVPUd6wNZ8e_LJqfRNcp16owQ',
    appId: '1:770312400067:android:8fa49e2495215277fc0676',
    messagingSenderId: '770312400067',
    projectId: 'studymate-ai-9e018',
    storageBucket: 'studymate-ai-9e018.firebasestorage.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBidB_27GHceLODvre-uU0ACA1L9bb-xRo',
    appId: '1:770312400067:web:79d0c0c9e31cdce5fc0676',
    messagingSenderId: '770312400067',
    projectId: 'studymate-ai-9e018',
    authDomain: 'studymate-ai-9e018.firebaseapp.com',
    storageBucket: 'studymate-ai-9e018.firebasestorage.app',
    measurementId: 'G-W3NYK4PV3B',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAWu6DoRMksFiio7cVltTeg-ALuHumuTME',
    appId: '1:770312400067:ios:567c6048f0f57a7dfc0676',
    messagingSenderId: '770312400067',
    projectId: 'studymate-ai-9e018',
    storageBucket: 'studymate-ai-9e018.firebasestorage.app',
    iosBundleId: 'in.edu.diploma.studymateAi',
  );
}
