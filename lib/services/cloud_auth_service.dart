import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

enum EmailAuthResult {
  success,
  invalidEmail,
  invalidCredentials,
  weakPassword,
  emailAlreadyInUse,
  tooManyRequests,
  networkError,
  unavailable,
  failed,
}

/// Anonymous-by-default identity: every configured web player gets a silent
/// anonymous Firebase account. Login is optional and uses email/password.
///
/// Methods fail closed when Firebase is unavailable. Configured web builds use
/// this identity for leaderboards and multiplayer; native remains disabled.
class CloudAuthService extends ChangeNotifier {
  User? _user;
  bool _available = false;
  StreamSubscription<User?>? _authSubscription;

  bool get available => _available;
  User? get currentUser => _user;
  String? get uid => _user?.uid;
  String? get email => _user?.email;
  bool get isAnonymous => _user?.isAnonymous ?? true;

  String get shortPlayerId {
    final value = uid;
    if (value == null || value.isEmpty) return 'OFFLINE';
    final length = value.length < 6 ? value.length : 6;
    return value.substring(0, length).toUpperCase();
  }

  /// Silently signs in anonymously on first launch. Firebase Auth persists the
  /// session, so later launches recover the same anonymous or email account.
  Future<void> initialize() async {
    if (!isFirebaseConfigured) return;
    try {
      final auth = FirebaseAuth.instance;
      _authSubscription = auth.authStateChanges().listen((user) {
        _user = user;
        _available = user != null;
        notifyListeners();
      });
      _user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      _available = _user != null;
    } catch (_) {
      // Offline first launch or unavailable Firebase must not block play.
      _available = false;
    }
    notifyListeners();
  }

  /// Links a new email/password credential to the current anonymous player,
  /// preserving its UID and existing leaderboard entries.
  Future<EmailAuthResult> createEmailAccount({
    required String email,
    required String password,
  }) async {
    if (!isFirebaseConfigured || !_available || _user == null) {
      return EmailAuthResult.unavailable;
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      final result = _user!.isAnonymous
          ? await _user!.linkWithCredential(credential)
          : await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
      _user = result.user;
      _available = _user != null;
      notifyListeners();
      try {
        await _user?.sendEmailVerification();
      } catch (_) {
        // The account exists even if the verification email could not send.
      }
      return _user == null ? EmailAuthResult.failed : EmailAuthResult.success;
    } catch (error) {
      return _emailFailure(error);
    }
  }

  /// Restores an existing email/password identity and its leaderboard UID.
  /// Scores and settings remain device-local while cloud backup is disabled.
  Future<EmailAuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (!isFirebaseConfigured) return EmailAuthResult.unavailable;
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = result.user;
      _available = _user != null;
      notifyListeners();
      return _user == null ? EmailAuthResult.failed : EmailAuthResult.success;
    } catch (error) {
      return _emailFailure(error);
    }
  }

  Future<EmailAuthResult> sendPasswordReset(String email) async {
    if (!isFirebaseConfigured) return EmailAuthResult.unavailable;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return EmailAuthResult.success;
    } catch (error) {
      return _emailFailure(error);
    }
  }

  EmailAuthResult _emailFailure(Object error) {
    if (error is! FirebaseAuthException) return EmailAuthResult.failed;
    return switch (error.code) {
      'invalid-email' => EmailAuthResult.invalidEmail,
      'weak-password' => EmailAuthResult.weakPassword,
      'email-already-in-use' ||
      'credential-already-in-use' => EmailAuthResult.emailAlreadyInUse,
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' ||
      'invalid-login-credentials' => EmailAuthResult.invalidCredentials,
      'too-many-requests' => EmailAuthResult.tooManyRequests,
      'network-request-failed' => EmailAuthResult.networkError,
      'operation-not-allowed' => EmailAuthResult.unavailable,
      _ => EmailAuthResult.failed,
    };
  }

  /// Logs out of an email account and starts a fresh anonymous identity.
  Future<bool> useNewAnonymousAccount() async {
    if (!isFirebaseConfigured) return false;
    try {
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      final result = await auth.signInAnonymously();
      _user = result.user;
      _available = _user != null;
      notifyListeners();
      return _user != null;
    } catch (_) {
      return false;
    }
  }

  /// Reserved for the future complete online-data deletion workflow.
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

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
