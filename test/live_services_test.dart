import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/firebase_options.dart';
import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/services/analytics_service.dart';
import 'package:whatthetetris/services/cloud_auth_service.dart';
import 'package:whatthetetris/services/cloud_backup_service.dart';
import 'package:whatthetetris/services/high_score_service.dart';
import 'package:whatthetetris/services/leaderboard_service.dart';
import 'package:whatthetetris/services/live_services.dart';
import 'package:whatthetetris/services/purchase_service.dart';
import 'package:whatthetetris/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'native tests stay disabled while production web options are present',
    () {
      // flutter test runs on a native VM. Web configuration must not activate
      // placeholder Android/iOS options here.
      expect(isFirebaseConfigured, isFalse);
      expect(isFirebaseCloudBackupConfigured, isFalse);
      expect(isFirebaseLeaderboardConfigured, isFalse);
      expect(DefaultFirebaseOptions.web.projectId, 'whatthetetris');
      expect(
        DefaultFirebaseOptions.web.appId,
        '1:219212649574:web:64b03f4bad30d8269689a7',
      );
    },
  );

  test(
    'CloudAuthService.initialize degrades to unavailable, never throws',
    () async {
      final auth = CloudAuthService();
      await auth.initialize();

      expect(auth.available, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.uid, isNull);
    },
  );

  test('CloudAuthService email calls all fail closed, never throw', () async {
    final auth = CloudAuthService();
    await auth.initialize();

    expect(
      await auth.loginWithEmail(
        email: 'player@example.com',
        password: 'triangle123',
      ),
      EmailAuthResult.unavailable,
    );
    expect(
      await auth.createEmailAccount(
        email: 'player@example.com',
        password: 'triangle123',
      ),
      EmailAuthResult.unavailable,
    );
    expect(
      await auth.sendPasswordReset('player@example.com'),
      EmailAuthResult.unavailable,
    );
    expect(await auth.deleteAccount(), isFalse);
    expect(await auth.updatePlayerName('Triangle Ace'), isFalse);
  });

  test('player names normalize and reject unsafe public labels', () {
    expect(
      CloudAuthService.normalizePlayerName('  Triangle   Ace  '),
      'Triangle Ace',
    );
    expect(CloudAuthService.isValidPlayerName('Triangle Ace'), isTrue);
    expect(CloudAuthService.isValidPlayerName('A'), isFalse);
    expect(CloudAuthService.isValidPlayerName('name@example.com'), isFalse);
    expect(CloudAuthService.isValidPlayerName('<script>'), isFalse);
  });

  test(
    'CloudBackupService is unavailable and every call is a safe no-op',
    () async {
      SharedPreferences.setMockInitialValues({});
      final auth = CloudAuthService();
      await auth.initialize();
      final backup = CloudBackupService(auth);
      final highScores = await HighScoreService.create();
      final stats = await StatsService.create();

      expect(backup.available, isFalse);

      await backup.pushSaves(highScores: highScores, stats: stats);
      expect(backup.lastSyncedAt, isNull); // never actually synced

      expect(await backup.deleteAllData(), isFalse);
    },
  );

  test('AnalyticsService logging is a safe no-op in native tests', () async {
    final analytics = AnalyticsService();

    await analytics.identifyAnonymousPlayer('anonymous-test-uid');
    await analytics.sessionStart();
    await analytics.screenViewed('mode_select');
    await analytics.modeSelected(GameMode.classic);
    await analytics.featureSelected('settings');
    await analytics.dailyRetry(previouslyCleared: true);
    await analytics.gameStart(GameMode.classic);
    await analytics.gameOver(
      mode: GameMode.classic,
      score: 100,
      level: 1,
      lines: 5,
      durationMs: 1000,
      isNewBest: true,
    );
    await analytics.mirrorUsed();
    await analytics.cavityFillUsed();
    await analytics.fusionBonus(2);
    await analytics.fourLineClear();
    await analytics.combo(3);
    await analytics.multiplayerLobbyViewed(available: true);
    await analytics.multiplayerLobbyAction(
      action: 'create_room',
      result: 'attempted',
    );
    await analytics.multiplayerConnection(
      result: 'success',
      role: 'host',
      waitMs: 500,
    );
    await analytics.multiplayerRoundStarted(role: 'host', roundNumber: 1);
    await analytics.multiplayerRoundEnded(
      role: 'host',
      reason: 'top_out',
      roundNumber: 1,
      durationMs: 30000,
      score: 1200,
      lines: 8,
      moves: 42,
      rotations: 12,
      softDrops: 8,
      hardDrops: 14,
    );
    await analytics.multiplayerRestarted(role: 'host', completedRounds: 1);
    // If any of the above throws, this test fails — that's the contract.
  });

  test(
    'PurchaseService.initialize refuses to configure against the placeholder key',
    () async {
      final purchases = PurchaseService();
      await purchases.initialize();

      expect(purchases.isConfigured, isFalse);
      expect(purchases.isVip, isFalse);
      expect(purchases.offerings, isNull);

      // Every downstream call stays a safe no-op too.
      await purchases.refresh();
      expect(await purchases.restorePurchases(), isFalse);
    },
  );

  test(
    'LeaderboardService is unavailable and every call is a safe no-op',
    () async {
      final auth = CloudAuthService();
      await auth.initialize();
      final leaderboard = LeaderboardService(auth);

      expect(leaderboard.available, isFalse);
      expect(
        await leaderboard.submitScore(
          mode: GameMode.chill,
          score: 100,
          level: 1,
          isNewBest: true,
        ),
        isFalse,
      );
      expect(await leaderboard.fetchTop(mode: GameMode.classic), isEmpty);
      expect(
        await leaderboard.submitMultiplayerScore(
          score: 200,
          level: 1,
          isNewBest: true,
        ),
        isFalse,
      );
      expect(await leaderboard.fetchTopMultiplayer(), isEmpty);
    },
  );

  test('LiveServices.create() bundles all five without throwing', () async {
    SharedPreferences.setMockInitialValues({});
    final live = await LiveServices.create();

    expect(live.auth.available, isFalse);
    expect(live.backup.available, isFalse);
    expect(live.purchases.isConfigured, isFalse);
    expect(live.leaderboard.available, isFalse);
  });
}
