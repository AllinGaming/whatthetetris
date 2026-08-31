// Production Firebase web configuration. Android and Apple remain disabled
// until their own platform apps are registered with `flutterfire configure`;
// a Firebase web app ID is not valid native-platform configuration.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase Core and anonymous Auth are enabled on web for Analytics and
/// authenticated multiplayer signaling. Individual features have separate
/// flags so this does not silently activate cloud backup.
bool get isFirebaseConfigured => kIsWeb;
bool get isFirebaseAnalyticsConfigured => kIsWeb;
bool get isFirebaseMultiplayerConfigured => kIsWeb;
bool get isFirebaseCloudBackupConfigured => false;
bool get isFirebaseLeaderboardConfigured => kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this '
          'platform — run `flutterfire configure`.',
        );
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDAjFELmnP3oaHJh7cVAeEFB5nBPqYvTNk',
    appId: '1:219212649574:web:64b03f4bad30d8269689a7',
    messagingSenderId: '219212649574',
    projectId: 'whatthetetris',
    authDomain: 'whatthetetris.firebaseapp.com',
    storageBucket: 'whatthetetris.firebasestorage.app',
    measurementId: 'G-04PRRQ6JX4',
  );

  static const android = FirebaseOptions(
    apiKey: 'placeholder-not-a-real-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'whatthetetris-placeholder',
    storageBucket: 'whatthetetris-placeholder.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'placeholder-not-a-real-key',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'whatthetetris-placeholder',
    storageBucket: 'whatthetetris-placeholder.appspot.com',
    iosBundleId: 'com.allingaming.whatthetetris',
  );
}
