import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/models/achievement.dart';
import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/services/daily_challenge_service.dart';
import 'package:whatthetetris/services/high_score_service.dart';
import 'package:whatthetetris/services/stats_service.dart';

void main() {
  test('recordRun accumulates lifetime totals and tracks bests', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 10,
      tetrises: 1,
      fusionBonuses: 2,
      bestCombo: 3,
      bestBackToBack: 1,
      playtimeMs: 60000,
      mirrorUses: 4,
      cavityFills: 2,
    );
    await stats.recordRun(
      mode: GameMode.arcade,
      linesCleared: 5,
      tetrises: 0,
      fusionBonuses: 1,
      bestCombo: 1,
      bestBackToBack: 0,
      playtimeMs: 30000,
      mirrorUses: 1,
      cavityFills: 0,
    );

    expect(stats.gamesPlayed, 2);
    expect(stats.totalLinesCleared, 15);
    expect(stats.totalTetrises, 1);
    expect(stats.totalFusionBonuses, 3);
    expect(stats.bestComboEver, 3); // max across runs, not sum
    expect(stats.bestBackToBackEver, 1);
    expect(stats.totalPlaytimeMs, 90000);
    expect(stats.totalMirrorUses, 5);
    expect(stats.totalCavityFills, 2);
    expect(stats.modesPlayed, {'classic', 'arcade'});
  });

  test('achievements unlock only once their threshold is reached', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();
    final highScores = await HighScoreService.create();
    final dailyChallenge = await DailyChallengeService.create();
    final ctx = AchievementContext(
      stats: stats,
      highScores: highScores,
      dailyChallenge: dailyChallenge,
    );

    final firstClear = Achievement.all.firstWhere((a) => a.id == 'first_clear');
    expect(firstClear.isUnlocked(ctx), isFalse);

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 1,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: 1000,
    );

    expect(firstClear.isUnlocked(ctx), isTrue);
    final lineCruncher = Achievement.all.firstWhere(
      (a) => a.id == 'line_cruncher',
    );
    expect(lineCruncher.isUnlocked(ctx), isFalse);
  });

  test('mirror/cavity-fill achievements track their own counters', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();
    final highScores = await HighScoreService.create();
    final dailyChallenge = await DailyChallengeService.create();
    final ctx = AchievementContext(
      stats: stats,
      highScores: highScores,
      dailyChallenge: dailyChallenge,
    );

    final mirrorNovice = Achievement.all.firstWhere(
      (a) => a.id == 'mirror_novice',
    );
    final cavityCrusher = Achievement.all.firstWhere(
      (a) => a.id == 'cavity_crusher',
    );
    expect(mirrorNovice.isUnlocked(ctx), isFalse);
    expect(cavityCrusher.isUnlocked(ctx), isFalse);

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: 0,
      mirrorUses: 10,
      cavityFills: 100,
    );

    expect(mirrorNovice.isUnlocked(ctx), isTrue);
    expect(cavityCrusher.isUnlocked(ctx), isTrue);
  });

  test(
    'daily challenger unlocks off DailyChallengeService.completedCount',
    () async {
      // A real player can complete at most one Daily Challenge per calendar
      // day (recordResult is idempotent per day — see
      // daily_challenge_service_test.dart), so 7 completions means 7
      // distinct days, not 7 same-day calls. Seed 6 already-completed days
      // (most recently yesterday, to keep the streak alive) and let one
      // legitimate today's-run call cross the threshold.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey =
          '${yesterday.year.toString().padLeft(4, '0')}'
          '${yesterday.month.toString().padLeft(2, '0')}'
          '${yesterday.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'daily_completed_count': 6,
        'daily_last_played_date': yesterdayKey,
        'daily_streak': 6,
      });
      final stats = await StatsService.create();
      final highScores = await HighScoreService.create();
      final dailyChallenge = await DailyChallengeService.create();
      final ctx = AchievementContext(
        stats: stats,
        highScores: highScores,
        dailyChallenge: dailyChallenge,
      );

      final dailyChallenger = Achievement.all.firstWhere(
        (a) => a.id == 'daily_challenger',
      );
      expect(dailyChallenger.isUnlocked(ctx), isFalse);

      await dailyChallenge.recordResult(100);

      expect(dailyChallenge.completedCount, 7);
      expect(dailyChallenger.isUnlocked(ctx), isTrue);
    },
  );

  test('every achievement has a unique id', () {
    final ids = Achievement.all.map((a) => a.id).toSet();
    expect(ids.length, Achievement.all.length);
  });

  test('cavity_novice unlocks on the very first cavity fill', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();
    final highScores = await HighScoreService.create();
    final dailyChallenge = await DailyChallengeService.create();
    final ctx = AchievementContext(
      stats: stats,
      highScores: highScores,
      dailyChallenge: dailyChallenge,
    );
    final cavityNovice = Achievement.all.firstWhere(
      (a) => a.id == 'cavity_novice',
    );
    expect(cavityNovice.isUnlocked(ctx), isFalse);

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: 0,
      cavityFills: 1,
    );

    expect(cavityNovice.isUnlocked(ctx), isTrue);
  });

  test('back_to_back_master needs a 5-chain, not just any chain', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();
    final highScores = await HighScoreService.create();
    final dailyChallenge = await DailyChallengeService.create();
    final ctx = AchievementContext(
      stats: stats,
      highScores: highScores,
      dailyChallenge: dailyChallenge,
    );
    final master = Achievement.all.firstWhere(
      (a) => a.id == 'back_to_back_master',
    );

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 4,
      playtimeMs: 0,
    );
    expect(master.isUnlocked(ctx), isFalse);

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 5,
      playtimeMs: 0,
    );
    expect(master.isUnlocked(ctx), isTrue);
  });

  test('iron_will needs 10 hours, not just Dedicated\'s 1 hour', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();
    final highScores = await HighScoreService.create();
    final dailyChallenge = await DailyChallengeService.create();
    final ctx = AchievementContext(
      stats: stats,
      highScores: highScores,
      dailyChallenge: dailyChallenge,
    );
    final ironWill = Achievement.all.firstWhere((a) => a.id == 'iron_will');
    final dedicated = Achievement.all.firstWhere((a) => a.id == 'dedicated');

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: const Duration(hours: 2).inMilliseconds,
    );
    expect(dedicated.isUnlocked(ctx), isTrue);
    expect(ironWill.isUnlocked(ctx), isFalse);

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: const Duration(hours: 8).inMilliseconds,
    );
    expect(ironWill.isUnlocked(ctx), isTrue);
  });

  test(
    'classic_grinder and zen_master track their own mode\'s level',
    () async {
      SharedPreferences.setMockInitialValues({});
      final stats = await StatsService.create();
      final highScores = await HighScoreService.create();
      final dailyChallenge = await DailyChallengeService.create();
      final ctx = AchievementContext(
        stats: stats,
        highScores: highScores,
        dailyChallenge: dailyChallenge,
      );
      final classicGrinder = Achievement.all.firstWhere(
        (a) => a.id == 'classic_grinder',
      );
      final zenMaster = Achievement.all.firstWhere((a) => a.id == 'zen_master');

      // Reaching the threshold in Arcade shouldn't unlock Classic's or Zen's.
      await highScores.submitRun(GameMode.arcade, score: 0, level: 20);
      expect(classicGrinder.isUnlocked(ctx), isFalse);
      expect(zenMaster.isUnlocked(ctx), isFalse);

      await highScores.submitRun(GameMode.classic, score: 0, level: 20);
      expect(classicGrinder.isUnlocked(ctx), isTrue);
      expect(zenMaster.isUnlocked(ctx), isFalse);

      await highScores.submitRun(GameMode.zen, score: 0, level: 10);
      expect(zenMaster.isUnlocked(ctx), isTrue);
    },
  );

  test('overdrive needs the full 8-stack, not a partial boost', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();
    final highScores = await HighScoreService.create();
    final dailyChallenge = await DailyChallengeService.create();
    final ctx = AchievementContext(
      stats: stats,
      highScores: highScores,
      dailyChallenge: dailyChallenge,
    );
    final overdrive = Achievement.all.firstWhere((a) => a.id == 'overdrive');

    await stats.recordRun(
      mode: GameMode.arcade,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: 0,
      maxSpeedBoost: 5,
    );
    expect(overdrive.isUnlocked(ctx), isFalse);
    expect(stats.maxSpeedBoostEver, 5);

    await stats.recordRun(
      mode: GameMode.arcade,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: 0,
      maxSpeedBoost: 8,
    );
    expect(overdrive.isUnlocked(ctx), isTrue);

    // A later, lower-boost run must not walk the peak back down.
    await stats.recordRun(
      mode: GameMode.arcade,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: 0,
      maxSpeedBoost: 2,
    );
    expect(stats.maxSpeedBoostEver, 8);
  });

  test('daily_devotee is a longer-term tier above daily_challenger', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year.toString().padLeft(4, '0')}'
        '${yesterday.month.toString().padLeft(2, '0')}'
        '${yesterday.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'daily_completed_count': 29,
      'daily_last_played_date': yesterdayKey,
      'daily_streak': 29,
    });
    final stats = await StatsService.create();
    final highScores = await HighScoreService.create();
    final dailyChallenge = await DailyChallengeService.create();
    final ctx = AchievementContext(
      stats: stats,
      highScores: highScores,
      dailyChallenge: dailyChallenge,
    );
    final devotee = Achievement.all.firstWhere((a) => a.id == 'daily_devotee');
    expect(devotee.isUnlocked(ctx), isFalse);

    await dailyChallenge.recordResult(100);

    expect(dailyChallenge.completedCount, 30);
    expect(devotee.isUnlocked(ctx), isTrue);
  });

  test(
    'recentForm appends ratios oldest-first and caps at 20 entries',
    () async {
      SharedPreferences.setMockInitialValues({});
      final stats = await StatsService.create();

      for (var i = 0; i < 25; i++) {
        await stats.recordRun(
          mode: GameMode.classic,
          linesCleared: 0,
          tetrises: 0,
          fusionBonuses: 0,
          bestCombo: 0,
          bestBackToBack: 0,
          playtimeMs: 0,
          formRatio: i / 100,
        );
      }

      expect(stats.recentForm.length, 20);
      // The oldest 5 (ratios 0.00-0.04) were pushed out; 0.05 is now oldest.
      expect(stats.recentForm.first, closeTo(0.05, 1e-9));
      expect(stats.recentForm.last, closeTo(0.24, 1e-9));
    },
  );

  test('recentForm clamps out-of-range ratios into 0.0-1.0', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 0,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: 0,
      formRatio: 1.5,
    );

    expect(stats.recentForm.single, 1.0);
  });

  test('a run with no formRatio leaves the history untouched', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.create();

    await stats.recordRun(
      mode: GameMode.classic,
      linesCleared: 1,
      tetrises: 0,
      fusionBonuses: 0,
      bestCombo: 0,
      bestBackToBack: 0,
      playtimeMs: 0,
    );

    expect(stats.recentForm, isEmpty);
  });
}
