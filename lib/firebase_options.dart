// PLACEHOLDER — not a real Firebase project.
//
// This file exists so the live-services code (docs/TECHNICAL_ARCHITECTURE.md)
// compiles and runs today, but every value below is a non-functional stand-in.
// Firebase.initializeApp() will "succeed" (the SDK just stores this config
// locally) but every subsequent call — sign-in, Firestore reads/writes,
// analytics — will fail, which is exactly why every caller in this codebase
// wraps those calls in try/catch and degrades to local-only behavior.
//
// To go live:
//   1. Create a project at https://console.firebase.google.com
//   2. Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`
//   3. Run `flutterfire configure` from the project root and let it
//      overwrite this entire file with real, generated values.
//   4. Do the same for a second (dev) project if you want separate
//      dev/prod environments per docs/TECHNICAL_ARCHITECTURE.md SS2.
//
// Do not hand-edit the placeholder values below to "look more real" — a
// half-fake config is more confusing than an honestly-labeled placeholder.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// True until [DefaultFirebaseOptions] is replaced by a real
/// `flutterfire configure` run. Services check this before attempting any
/// network call, rather than relying on every call site to catch failures.
const bool isFirebaseConfigured = false;

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
    apiKey: 'placeholder-not-a-real-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'whatthetetris-placeholder',
    authDomain: 'whatthetetris-placeholder.firebaseapp.com',
    storageBucket: 'whatthetetris-placeholder.appspot.com',
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
