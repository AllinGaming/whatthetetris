import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';

/// Anonymous-by-default identity (docs/TECHNICAL_ARCHITECTURE.md SS3): every
/// install gets a silent anonymous account with no UI, ever. Linking to
/// Apple/Google is purely optional, offered from Settings as "back up my
/// progress" — never required to play.
///
/// Every method here is a no-op (or returns a clear failure) when
/// [isFirebaseConfigured] is false, so the rest of the app never needs to
/// know whether live services actually exist yet.
class CloudAuthService extends ChangeNotifier {
  User? _user;
  bool _available = false;

  /// True once anonymous sign-in has actually succeeded against a real
  /// Firebase project. False for the placeholder config, or if the device
  /// has no network the first time it's ever launched.
  bool get available => _available;

  User? get currentUser => _user;
  String? get uid => _user?.uid;

  /// True once the anonymous credential has been linked to a real
  /// provider (Apple/Google) — meaning progress can be restored on another
  /// device, not just recovered on this one.
  bool get isBackedUp => _user?.providerData.isNotEmpty ?? false;

  List<String> get linkedProviders =>
      _user?.providerData.map((p) => p.providerId).toList() ?? const [];

  /// Silently signs in anonymously on first call. Safe to call every app
  /// launch — Firebase Auth persists the session, so this is a no-op
  /// after the first real launch.
  Future<void> initialize() async {
    if (!isFirebaseConfigured) return;
    try {
      final auth = FirebaseAuth.instance;
      auth.authStateChanges().listen((user) {
        _user = user;
        notifyListeners();
      });
      _user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      _available = true;
    } catch (_) {
      // No network on first launch, or the placeholder config — either
      // way, the app must keep working fully offline/local.
      _available = false;
    }
    notifyListeners();
  }

  /// Links the current (anonymous) session to a Google account so progress
  /// survives a reinstall. Returns false rather than throwing on any
  /// failure — callers show a plain "couldn't back up right now" message.
  Future<bool> linkWithGoogle() async {
    if (!_available || _user == null) return false;
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false; // user cancelled
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _user!.linkWithCredential(credential);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Links the current (anonymous) session to Sign in with Apple. Ships
  /// alongside [linkWithGoogle], not staggered after it — offering Google
  /// sign-in on iOS without also offering Apple violates App Store Review
  /// Guideline 4.8 (docs/TECHNICAL_ARCHITECTURE.md SS6).
  Future<bool> linkWithApple() async {
    if (!_available || _user == null) return false;
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      await _user!.linkWithCredential(oauthCredential);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restores progress on a new/reinstalled device: signs in with the
  /// provider credential (not link — this device's throwaway anonymous
  /// session is discarded in favor of the account that credential already
  /// belongs to).
  Future<bool> restoreWithGoogle() async {
    if (!isFirebaseConfigured) return false;
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      _user = result.user;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreWithApple() async {
    if (!isFirebaseConfigured) return false;
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(
        oauthCredential,
      );
      _user = result.user;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes the Firebase Auth user. The corresponding Firestore document
  /// tree is removed by [CloudBackupService.deleteAllData] — call that
  /// first, since a deleted user can no longer authenticate the request.
  /// Required the moment account linking exists (App Store Review
  /// Guideline 5.1.1(v)), not optional polish.
  Future<bool> deleteAccount() async {
    if (_user == null) return false;
    try {
      await _user!.delete();
      _user = null;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
