import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// STUB FIREBASE OPTIONS
/// Run `flutterfire configure` to generate the real configuration file.
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
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'STUB_API_KEY_ANDROID',
    appId: '1:1234567890:android:abcdef0123456789',
    messagingSenderId: '1234567890',
    projectId: 'studymate-ai-stub',
    storageBucket: 'studymate-ai-stub.appspot.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'STUB_API_KEY_WEB',
    appId: '1:1234567890:web:abcdef0123456789',
    messagingSenderId: '1234567890',
    projectId: 'studymate-ai-stub',
    authDomain: 'studymate-ai-stub.firebaseapp.com',
    storageBucket: 'studymate-ai-stub.appspot.com',
    measurementId: 'G-1234567890',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'STUB_API_KEY_IOS',
    appId: '1:1234567890:ios:abcdef0123456789',
    messagingSenderId: '1234567890',
    projectId: 'studymate-ai-stub',
    storageBucket: 'studymate-ai-stub.appspot.com',
    iosBundleId: 'in.edu.diploma.studymateAi',
  );
}
