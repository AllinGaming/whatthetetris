import 'package:flutter/foundation.dart';

import '../services/daily_challenge_service.dart';
import '../services/high_score_service.dart';
import '../services/stats_service.dart';
import 'game_mode.dart';

/// A snapshot of everything an achievement predicate might need. Bundled so
/// [Achievement.isUnlocked] doesn't need to know which service backs which
/// figure.
@immutable
class AchievementContext {
  const AchievementContext({
    required this.stats,
    required this.highScores,
    required this.dailyChallenge,
  });

  final StatsService stats;
  final HighScoreService highScores;
  final DailyChallengeService dailyChallenge;
}

@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.progress,
  });

  final String id;
  final String title;
  final String description;
  final bool Function(AchievementContext ctx) isUnlocked;

  /// A short "42/100"-style progress string, or null when a bare
  /// locked/unlocked state is all that makes sense (e.g. "play every mode").
  final String? Function(AchievementContext ctx) progress;

  /// Spans onboarding, mastery, and endurance across every mode
  /// (docs/GDD.md SS6.2) — 29 entries, within the design doc's 20-30 target.
  static final List<Achievement> all = [
    Achievement(
      id: 'first_clear',
      title: 'First Clear',
      description: 'Clear your first line.',
      isUnlocked: (ctx) => ctx.stats.totalLinesCleared >= 1,
      progress: (ctx) => null,
    ),
    Achievement(
      id: 'line_cruncher',
      title: 'Line Cruncher',
      description: 'Clear 100 lines, lifetime.',
      isUnlocked: (ctx) => ctx.stats.totalLinesCleared >= 100,
      progress: (ctx) => '${ctx.stats.totalLinesCleared.clamp(0, 100)}/100',
    ),
    Achievement(
      id: 'century',
      title: 'Century',
      description: 'Clear 1,000 lines, lifetime.',
      isUnlocked: (ctx) => ctx.stats.totalLinesCleared >= 1000,
      progress: (ctx) => '${ctx.stats.totalLinesCleared.clamp(0, 1000)}/1000',
    ),
    Achievement(
      id: 'four_line_clear',
      title: 'Triangle!',
      description: 'Clear four lines at once.',
      isUnlocked: (ctx) => ctx.stats.totalFourLineClears >= 1,
      progress: (ctx) => null,
    ),
    Achievement(
      id: 'four_line_master',
      title: 'Triangle Master',
      description: 'Clear four lines at once 25 times, lifetime.',
      isUnlocked: (ctx) => ctx.stats.totalFourLineClears >= 25,
      progress: (ctx) => '${ctx.stats.totalFourLineClears.clamp(0, 25)}/25',
    ),
    Achievement(
      id: 'fusion_novice',
      title: 'Fusion Novice',
      description: 'Trigger a Fusion Bonus.',
      isUnlocked: (ctx) => ctx.stats.totalFusionBonuses >= 1,
      progress: (ctx) => null,
    ),
    Achievement(
      id: 'fusion_master',
      title: 'Fusion Master',
      description: 'Trigger 100 Fusion Bonuses, lifetime.',
      isUnlocked: (ctx) => ctx.stats.totalFusionBonuses >= 100,
      progress: (ctx) => '${ctx.stats.totalFusionBonuses.clamp(0, 100)}/100',
    ),
    Achievement(
      id: 'combo_starter',
      title: 'Combo Starter',
      description: 'Reach a 3x combo in one run.',
      isUnlocked: (ctx) => ctx.stats.bestComboEver >= 3,
      progress: (ctx) => null,
    ),
    Achievement(
      id: 'combo_king',
      title: 'Combo King',
      description: 'Reach an 8x combo in one run.',
      isUnlocked: (ctx) => ctx.stats.bestComboEver >= 8,
      progress: (ctx) => null,
    ),
    Achievement(
      id: 'back_to_back',
      title: 'Back-to-Back',
      description: 'Land a back-to-back bonus.',
      isUnlocked: (ctx) => ctx.stats.bestBackToBackEver >= 1,
      progress: (ctx) => null,
    ),
    Achievement(
      id: 'marathoner',
      title: 'Marathoner',
      description: 'Play 10 games, lifetime.',
      isUnlocked: (ctx) => ctx.stats.gamesPlayed >= 10,
      progress: (ctx) => '${ctx.stats.gamesPlayed.clamp(0, 10)}/10',
    ),
    Achievement(
      id: 'veteran',
      title: 'Veteran',
      description: 'Play 100 games, lifetime.',
      isUnlocked: (ctx) => ctx.stats.gamesPlayed >= 100,
      progress: (ctx) => '${ctx.stats.gamesPlayed.clamp(0, 100)}/100',
    ),
    Achievement(
      id: 'dedicated',
      title: 'Dedicated',
      description: 'Accumulate 1 hour of playtime.',
      isUnlocked: (ctx) =>
          ctx.stats.totalPlaytimeMs >= const Duration(hours: 1).inMilliseconds,
      progress: (ctx) {
        final minutes = ctx.stats.totalPlaytimeMs ~/ 60000;
        return '$minutes/60 min';
      },
    ),
    Achievement(
      id: 'mode_explorer',
      title: 'Mode Explorer',
      description: 'Play every game mode at least once.',
      isUnlocked: (ctx) =>
          GameMode.values.every((m) => ctx.stats.modesPlayed.contains(m.name)),
      progress: (ctx) =>
          '${ctx.stats.modesPlayed.length}/${GameMode.values.length} modes',
    ),
    Achievement(
      id: 'high_roller',
      title: 'High Roller',
      description: 'Reach level 15 in Arcade.',
      isUnlocked: (ctx) => ctx.highScores.bestLevel(GameMode.arcade) >= 15,
      progress: (ctx) =>
          '${ctx.highScores.bestLevel(GameMode.arcade).clamp(0, 15)}/15',
    ),
    Achievement(
      id: 'speed_demon',
      title: 'Speed Demon',
      description: 'Finish Sprint (40 lines) in under 90 seconds.',
      isUnlocked: (ctx) {
        final best = ctx.highScores.bestTimeMs(GameMode.sprint);
        return best != null && best < 90000;
      },
      progress: (ctx) => null,
    ),
    Achievement(
      id: 'mirror_novice',
      title: 'Mirror Novice',
      description: 'Flip the mirror 10 times, lifetime.',
      isUnlocked: (ctx) => ctx.stats.totalMirrorUses >= 10,
      progress: (ctx) => '${ctx.stats.totalMirrorUses.clamp(0, 10)}/10',
    ),
    Achievement(
      id: 'mirror_master',
      title: 'Mirror Master',
      description: 'Flip the mirror 250 times, lifetime.',
      isUnlocked: (ctx) => ctx.stats.totalMirrorUses >= 250,
      progress: (ctx) => '${ctx.stats.totalMirrorUses.clamp(0, 250)}/250',
    ),
    Achievement(
      id: 'cavity_crusher',
      title: 'Cavity Crusher',
      description: 'Fill 100 cavities, lifetime.',
      isUnlocked: (ctx) => ctx.stats.totalCavityFills >= 100,
      progress: (ctx) => '${ctx.stats.totalCavityFills.clamp(0, 100)}/100',
    ),
    Achievement(
      id: 'daily_challenger',
      title: 'Daily Challenger',
      description: 'Play the Daily Challenge on 7 different days.',
      isUnlocked: (ctx) => ctx.dailyChallenge.completedCount >= 7,
      progress: (ctx) => '${ctx.dailyChallenge.completedCount.clamp(0, 7)}/7',
    ),
    Achievement(
      id: 'chill_champion',
      title: 'Classic Contender',
      description: 'Reach level 5 in Classic.',
      isUnlocked: (ctx) => ctx.highScores.bestLevel(GameMode.chill) >= 5,
      progress: (ctx) =>
          '${ctx.highScores.bestLevel(GameMode.chill).clamp(0, 5)}/5',
    ),
    Achievement(
      id: 'ultra_scorer',
      title: 'Ultra Scorer',
      description: 'Score 10,000+ points in a single Ultra run.',
      isUnlocked: (ctx) => ctx.highScores.bestScore(GameMode.ultra) >= 10000,
      progress: (ctx) =>
          '${ctx.highScores.bestScore(GameMode.ultra).clamp(0, 10000)}/10000',
    ),
    Achievement(
      id: 'cavity_novice',
      title: 'Patch Job',
      description: 'Fill your first cavity.',
      isUnlocked: (ctx) => ctx.stats.totalCavityFills >= 1,
      progress: (ctx) => null,
    ),
    Achievement(
      id: 'back_to_back_master',
      title: 'On a Roll',
      description: 'Land a 5-chain Back-to-Back streak.',
      isUnlocked: (ctx) => ctx.stats.bestBackToBackEver >= 5,
      progress: (ctx) => '${ctx.stats.bestBackToBackEver.clamp(0, 5)}/5',
    ),
    Achievement(
      id: 'iron_will',
      title: 'Iron Will',
      description: 'Accumulate 10 hours of playtime.',
      isUnlocked: (ctx) =>
          ctx.stats.totalPlaytimeMs >= const Duration(hours: 10).inMilliseconds,
      progress: (ctx) {
        final hours = ctx.stats.totalPlaytimeMs / 3600000;
        return '${hours.toStringAsFixed(1)}/10 hr';
      },
    ),
    Achievement(
      id: 'classic_grinder',
      title: 'Classic Grinder',
      description: 'Reach level 20 in Classic.',
      isUnlocked: (ctx) => ctx.highScores.bestLevel(GameMode.chill) >= 20,
      progress: (ctx) =>
          '${ctx.highScores.bestLevel(GameMode.chill).clamp(0, 20)}/20',
    ),
    Achievement(
      id: 'zen_master',
      title: 'Zen Master',
      description: 'Reach level 10 in Zen.',
      isUnlocked: (ctx) => ctx.highScores.bestLevel(GameMode.zen) >= 10,
      progress: (ctx) =>
          '${ctx.highScores.bestLevel(GameMode.zen).clamp(0, 10)}/10',
    ),
    Achievement(
      id: 'overdrive',
      title: 'Overdrive',
      description: 'Max out Speed Boost (8 stacks) in a single Arcade run.',
      isUnlocked: (ctx) => ctx.stats.maxSpeedBoostEver >= 8,
      progress: (ctx) => '${ctx.stats.maxSpeedBoostEver.clamp(0, 8)}/8',
    ),
    Achievement(
      id: 'daily_devotee',
      title: 'Daily Devotee',
      description: 'Play the Daily Challenge on 30 different days.',
      isUnlocked: (ctx) => ctx.dailyChallenge.completedCount >= 30,
      progress: (ctx) => '${ctx.dailyChallenge.completedCount.clamp(0, 30)}/30',
    ),
  ];
}
