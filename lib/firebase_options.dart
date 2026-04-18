// lib/firebase_options.dart
// Generated from google-services.json for project: savyit-283c5
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAx0u685dFw0oDPFcESOpGJMhIJzv5gjb0',
    appId: '1:1025453755918:android:16a594e3fe91e0b59f765f',
    messagingSenderId: '1025453755918',
    projectId: 'savyit-283c5',
    storageBucket: 'savyit-283c5.firebasestorage.app',
  );
}
