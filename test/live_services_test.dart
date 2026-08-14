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
import 'package:whatthetetris/game/replay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'the placeholder Firebase config is honestly marked as not configured',
    () {
      // If this ever flips true without a real flutterfire configure run,
      // every guard in cloud_auth_service.dart/cloud_backup_service.dart/
      // analytics_service.dart would start making real network calls.
      expect(isFirebaseConfigured, isFalse);
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
      expect(auth.isBackedUp, isFalse);
    },
  );

  test(
    'CloudAuthService link/restore calls all fail closed, never throw',
    () async {
      final auth = CloudAuthService();
      await auth.initialize();

      expect(await auth.linkWithGoogle(), isFalse);
      expect(await auth.linkWithApple(), isFalse);
      expect(await auth.restoreWithGoogle(), isFalse);
      expect(await auth.restoreWithApple(), isFalse);
      expect(await auth.deleteAccount(), isFalse);
    },
  );

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

  test(
    'AnalyticsService logging never throws against the placeholder config',
    () async {
      final analytics = AnalyticsService();

      await analytics.sessionStart();
      await analytics.modeSelected(GameMode.classic);
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
      await analytics.tetrisClear();
      await analytics.combo(3);
      // If any of the above throws, this test fails — that's the contract.
    },
  );

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
      final replay = ReplayRecorder(seed: 1, mode: GameMode.classic).build();

      expect(leaderboard.available, isFalse);
      expect(
        await leaderboard.submitScore(
          mode: GameMode.classic,
          score: 100,
          level: 1,
          replay: replay,
        ),
        isFalse,
      );
      expect(await leaderboard.fetchTop(mode: GameMode.classic), isEmpty);
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
