import 'package:flutter/material.dart';

import '../game/game_screen.dart';
import '../models/game_mode.dart';
import '../services/high_score_service.dart';
import 'widgets/neon_text.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key, required this.highScores});

  final HighScoreService highScores;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'What The Tetris',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    shadows: neonShadows(Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Triangle-half Tetris. Pick a mode to start.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                _ModeCard(mode: GameMode.classic, highScores: highScores),
                const SizedBox(height: 16),
                _ModeCard(mode: GameMode.arcade, highScores: highScores),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.highScores});

  final GameMode mode;
  final HighScoreService highScores;

  @override
  Widget build(BuildContext context) {
    final cfg = mode.config;
    final accent = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.20),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GameScreen(mode: mode, highScores: highScores),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cfg.label,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cfg.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Best score: ${highScores.bestScore(mode)}   ·   Best level: ${highScores.bestLevel(mode)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.play_circle_fill, size: 36, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
