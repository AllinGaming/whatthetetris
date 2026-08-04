import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/game_mode.dart';
import '../models/piece.dart';
import 'widgets/floating_toast.dart';
import 'widgets/hold_repeat_button.dart';
import 'widgets/juicy_button.dart';
import 'widgets/neon_text.dart';
import 'widgets/next_piece_preview.dart';
import 'widgets/stat_row.dart';

class GameSidePanel extends StatelessWidget {
  const GameSidePanel({
    super.key,
    required this.width,
    required this.mode,
    required this.state,
    required this.score,
    required this.lines,
    required this.level,
    required this.bestScore,
    required this.bestLevel,
    required this.cavityCharges,
    required this.speedBoost,
    required this.upcoming,
    required this.toasts,
    required this.onRemoveToast,
    required this.onPauseOrPlay,
    required this.onRestart,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onSoftDrop,
    required this.onHardDrop,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onMirror,
    required this.onSpeedUp,
    required this.onFillCavities,
    required this.onMenu,
  });

  final double width;
  final GameMode mode;
  final GameState state;
  final int score;
  final int lines;
  final int level;
  final int bestScore;
  final int bestLevel;
  final int cavityCharges;
  final int speedBoost;
  final PieceDefinition upcoming;
  final Map<int, ToastData> toasts;
  final ValueChanged<int> onRemoveToast;
  final VoidCallback onPauseOrPlay;
  final VoidCallback onRestart;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onSoftDrop;
  final VoidCallback onHardDrop;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onMirror;
  final VoidCallback onSpeedUp;
  final VoidCallback onFillCavities;
  final VoidCallback onMenu;

  Widget _holdIcon(BuildContext context, IconData icon, VoidCallback onHold) {
    return HoldRepeatButton(
      onHold: onHold,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = mode.config;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(left: BorderSide(color: accent.withValues(alpha: 0.6), width: 2)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'What The Tetris',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      shadows: neonShadows(accent, intensity: 0.7),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu, color: Colors.white70),
                  tooltip: 'Menu',
                ),
              ],
            ),
            Text(
              '${cfg.label} mode',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: accent),
            ),
            const SizedBox(height: 8),
            Text(
              cfg.description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final entry in toasts.entries)
                    if (!entry.value.big)
                      FloatingToast(
                        key: ValueKey(entry.key),
                        data: entry.value,
                        onDone: () => onRemoveToast(entry.key),
                      ),
                ],
              ),
            ),
            StatRow(label: 'Score', value: score, best: bestScore),
            StatRow(label: 'Lines', value: lines),
            StatRow(label: 'Level', value: level, best: bestLevel),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Next',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.white54),
                ),
                const SizedBox(width: 10),
                NextPiecePreview(piece: upcoming),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                JuicyButton(
                  onPressed: onPauseOrPlay,
                  child: Text(state == GameState.paused ? 'Play' : 'Pause'),
                ),
                _holdIcon(context, Icons.arrow_back, onMoveLeft),
                _holdIcon(context, Icons.arrow_downward, onSoftDrop),
                _holdIcon(context, Icons.arrow_forward, onMoveRight),
                JuicyButton(
                  onPressed: onHardDrop,
                  child: const Text('Hard Drop'),
                ),
                JuicyButton(
                  onPressed: onRotateLeft,
                  child: const Text('⟲ Rotate Left'),
                ),
                JuicyButton(
                  onPressed: onRotateRight,
                  child: const Text('⟳ Rotate Right'),
                ),
                JuicyButton(
                  onPressed: onMirror,
                  child: const Text('Mirror (M)'),
                ),
                if (cfg.hasManualSpeedBoost)
                  JuicyButton(
                    onPressed: onSpeedUp,
                    child: Text('Speed Up (x${1 + speedBoost * 0.2})'),
                  ),
                if (cfg.hasCavityFiller)
                  JuicyButton(
                    onPressed: cavityCharges > 0 ? onFillCavities : null,
                    child: Text('Fill Cavities (G)  x$cavityCharges'),
                  ),
              ],
            ),
            if (state == GameState.over) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRestart,
                child: const Text('Play Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
