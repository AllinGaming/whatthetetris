import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/services/analytics_service.dart';
import 'package:whatthetetris/services/cloud_auth_service.dart';
import 'package:whatthetetris/services/cloud_backup_service.dart';
import 'package:whatthetetris/services/leaderboard_service.dart';
import 'package:whatthetetris/services/live_services.dart';
import 'package:whatthetetris/services/purchase_service.dart';
import 'package:whatthetetris/ui/account_screen.dart';
import 'package:whatthetetris/ui/legal_screen.dart';

class _FakeEmailAuthService extends CloudAuthService {
  String? lastEmail;
  String? lastPassword;

  @override
  bool get available => true;

  @override
  bool get isAnonymous => true;

  @override
  String get shortPlayerId => 'ABC123';

  @override
  Future<EmailAuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    return EmailAuthResult.success;
  }
}

LiveServices _liveWith(CloudAuthService auth) => LiveServices(
  auth: auth,
  backup: CloudBackupService(auth),
  analytics: AnalyticsService(),
  purchases: PurchaseService(),
  leaderboard: LeaderboardService(auth),
);

void main() {
  testWidgets('account screen keeps native/offline play available', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final live = await LiveServices.create();

    await tester.pumpWidget(MaterialApp(home: AccountScreen(live: live)));
    await tester.pumpAndSettle();

    expect(find.text('Login is unavailable'), findsOneWidget);
    expect(find.textContaining('work offline'), findsOneWidget);
  });

  testWidgets('account screen logs in with an email and password', (
    tester,
  ) async {
    final auth = _FakeEmailAuthService();

    await tester.pumpWidget(
      MaterialApp(home: AccountScreen(live: _liveWith(auth))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'player@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'triangle123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(auth.lastEmail, 'player@example.com');
    expect(auth.lastPassword, 'triangle123');
    expect(find.text('Logged in successfully.'), findsOneWidget);
  });

  testWidgets('privacy and terms documents are readable in app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final live = await LiveServices.create();

    await tester.pumpWidget(
      MaterialApp(home: LegalScreen(analytics: live.analytics)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Privacy Policy'), findsOneWidget);
    await tester.tap(find.text('Terms'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Terms of Use'), findsOneWidget);
  });
}
