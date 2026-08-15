import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/game_mode.dart';
import 'neon_text.dart';

/// The post-run recap — shown once per game-over, on top of the existing
/// board/side-panel UI. Ties together systems that already existed but
/// never met in one moment: the run's own stats, how it compares to your
/// best, and any achievement that just unlocked because of this run.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.mode,
    required this.score,
    required this.level,
    required this.lines,
    required this.isNewBest,
    this.challengeCleared = false,
    required this.durationMs,
    required this.fusions,
    required this.tetrises,
    required this.mirrorUses,
    required this.cavityFills,
    required this.newlyUnlocked,
    required this.onPlayAgain,
    required this.onShare,
    required this.onMenu,
  });

  final GameMode mode;
  final int score;
  final int level;
  final int lines;
  final bool isNewBest;

  /// True when this run just won a [GameMode.daily] puzzle board
  /// ([EndCondition.boardCleared]) — takes priority over [isNewBest] in the
  /// headline since it's the rarer, more specific signal.
  final bool challengeCleared;
  final int durationMs;
  final int fusions;
  final int tetrises;
  final int mirrorUses;
  final int cavityFills;
  final List<Achievement> newlyUnlocked;

  /// Null for [GameMode.daily] -- only one attempt is allowed per day, so
  /// there's nothing to play again until tomorrow (see `GameScreen._startGame`
  /// for the backstop that also blocks the other ways to trigger a restart).
  final VoidCallback? onPlayAgain;
  final VoidCallback onShare;
  final VoidCallback onMenu;

  String get _durationLabel {
    final d = Duration(milliseconds: durationMs);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final headlineColor = (challengeCleared || isNewBest)
        ? Colors.amberAccent
        : accent;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF14161F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: headlineColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: headlineColor.withValues(alpha: 0.25),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                challengeCleared
                    ? 'Board Cleared! 🎉'
                    : (isNewBest ? 'New Best!' : 'Run Complete'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: (challengeCleared || isNewBest)
                      ? Colors.amberAccent
                      : Colors.white,
                  shadows: neonShadows(headlineColor, intensity: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mode.config.label,
                textAlign: TextAlign.center,
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Text(
                '$score',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: neonShadows(accent, intensity: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'points',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 10,
                children: [
                  _Stat(label: 'Level', value: '$level'),
                  _Stat(label: 'Lines', value: '$lines'),
                  _Stat(label: 'Time', value: _durationLabel),
                  if (tetrises > 0)
                    _Stat(label: 'Tetrises', value: '$tetrises'),
                  if (fusions > 0) _Stat(label: 'Fusions', value: '$fusions'),
                  if (mirrorUses > 0)
                    _Stat(label: 'Mirror flips', value: '$mirrorUses'),
                  if (cavityFills > 0)
                    _Stat(label: 'Cavities filled', value: '$cavityFills'),
                ],
              ),
              if (newlyUnlocked.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                const Text(
                  'ACHIEVEMENT UNLOCKED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                for (final achievement in newlyUnlocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                achievement.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                achievement.description,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (onPlayAgain != null) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: onPlayAgain,
                        child: const Text('Play Again'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                    ),
                  ] else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onMenu, child: const Text('Menu')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
