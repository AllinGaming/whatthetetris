import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/daily_challenge_service.dart';
import '../services/high_score_service.dart';
import '../services/stats_service.dart';
import 'widgets/neon_text.dart';
import 'widgets/score_trend_sparkline.dart';

/// Lifetime stats + achievement list (docs/GDD.md SS6.1-SS6.2). Unlocked
/// state is derived live from [StatsService]/[HighScoreService] rather than
/// stored separately, since every underlying figure only ever goes up.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({
    super.key,
    required this.stats,
    required this.highScores,
    required this.dailyChallenge,
  });

  final StatsService stats;
  final HighScoreService highScores;
  final DailyChallengeService dailyChallenge;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final ctx = AchievementContext(
      stats: stats,
      highScores: highScores,
      dailyChallenge: dailyChallenge,
    );
    final unlockedCount = Achievement.all
        .where((a) => a.isUnlocked(ctx))
        .length;
    return ListenableBuilder(
      listenable: Listenable.merge([stats, highScores, dailyChallenge]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            'Stats & Achievements',
            style: TextStyle(shadows: neonShadows(accent, intensity: 0.6)),
          ),
        ),
        // SingleChildScrollView outside Center (not the other way around) so
        // its hit-testable width is the full screen -- otherwise it only
        // sizes itself to its centered, width-capped content, leaving dead
        // margins on wider screens where a drag silently does nothing
        // instead of scrolling.
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatsGrid(stats: stats),
                      const SizedBox(height: 20),
                      ScoreTrendSparkline(
                        values: stats.recentForm,
                        accent: accent,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'ACHIEVEMENTS  ($unlockedCount/${Achievement.all.length})',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final achievement in Achievement.all)
                        _AchievementTile(achievement: achievement, ctx: ctx),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final StatsService stats;

  @override
  Widget build(BuildContext context) {
    final minutes = stats.totalPlaytimeMs ~/ 60000;
    final entries = {
      'Games played': '${stats.gamesPlayed}',
      'Lines cleared': '${stats.totalLinesCleared}',
      'Tetrises': '${stats.totalTetrises}',
      'Fusion bonuses': '${stats.totalFusionBonuses}',
      'Best combo': '${stats.bestComboEver}x',
      'Mirror flips': '${stats.totalMirrorUses}',
      'Cavities filled': '${stats.totalCavityFills}',
      'Playtime': '$minutes min',
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final e in entries.entries)
          Container(
            width: 150,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  e.key,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.ctx});

  final Achievement achievement;
  final AchievementContext ctx;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked(ctx);
    final progress = achievement.progress(ctx);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: unlocked ? 0.06 : 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: unlocked ? Colors.amberAccent : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.emoji_events : Icons.lock_outline,
              color: unlocked ? Colors.amberAccent : Colors.white30,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: unlocked ? Colors.white : Colors.white54,
                    ),
                  ),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: unlocked ? Colors.white70 : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            if (progress != null)
              Text(
                progress,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }
}
