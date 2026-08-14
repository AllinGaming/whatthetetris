import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/game_mode.dart';
import '../models/piece.dart';
import '../models/theme_palette.dart';
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
    this.modeClock,
    required this.cavityCharges,
    required this.speedBoost,
    required this.upcoming,
    required this.upcomingColors,
    required this.held,
    required this.heldColor,
    required this.theme,
    required this.colorMode,
    required this.canHold,
    required this.canSpeedUp,
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
    required this.onHold,
    required this.onSpeedUp,
    required this.onFillCavities,
    required this.onMenu,
    required this.onShare,
  });

  final double width;
  final GameMode mode;
  final GameState state;
  final int score;
  final int lines;
  final int level;
  final int bestScore;
  final int bestLevel;
  final String? modeClock;
  final int cavityCharges;
  final int speedBoost;
  final List<PieceDefinition> upcoming;
  final List<Color> upcomingColors;
  final PieceDefinition? held;
  final Color? heldColor;
  final ThemePalette theme;
  final PieceColorMode colorMode;
  final bool canHold;
  final bool canSpeedUp;
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
  final VoidCallback onHold;
  final VoidCallback onSpeedUp;
  final VoidCallback onFillCavities;
  final VoidCallback onMenu;
  final VoidCallback onShare;

  Widget _holdIcon(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? onHold,
  ) {
    final child = Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: onHold != null,
        label: label,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onHold == null ? Colors.white38 : null,
          ),
        ),
      ),
    );
    return onHold == null
        ? child
        : HoldRepeatButton(onHold: onHold, semanticLabel: label, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = mode.config;
    final accent = Theme.of(context).colorScheme.primary;
    final controlsEnabled = state == GameState.playing;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.6), width: 2),
        ),
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
            if (modeClock != null) ...[
              const SizedBox(height: 6),
              Text(
                modeClock!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
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
            Text(
              'Next',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (int i = 0; i < upcoming.length && i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  NextPiecePreview(
                    piece: upcoming[i],
                    size: 44,
                    colorMode: colorMode,
                    colorOverride: upcomingColors[i],
                  ),
                ],
                const Spacer(),
                if (held != null)
                  NextPiecePreview(
                    piece: held!,
                    size: 44,
                    semanticLabel: 'Held piece',
                    colorMode: colorMode,
                    colorOverride: heldColor,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                JuicyButton(
                  onPressed: onPauseOrPlay,
                  child: Text(switch (state) {
                    GameState.playing => 'Pause',
                    GameState.paused => 'Resume',
                    GameState.over => 'Play Again',
                  }),
                ),
                _holdIcon(
                  context,
                  Icons.arrow_back,
                  'Move left',
                  controlsEnabled ? onMoveLeft : null,
                ),
                _holdIcon(
                  context,
                  Icons.arrow_downward,
                  'Soft drop',
                  controlsEnabled ? onSoftDrop : null,
                ),
                _holdIcon(
                  context,
                  Icons.arrow_forward,
                  'Move right',
                  controlsEnabled ? onMoveRight : null,
                ),
                JuicyButton(
                  onPressed: controlsEnabled ? onHardDrop : null,
                  child: const Text('Hard Drop'),
                ),
                JuicyButton(
                  onPressed: controlsEnabled ? onRotateLeft : null,
                  child: const Text('⟲ Rotate Left'),
                ),
                JuicyButton(
                  onPressed: controlsEnabled ? onRotateRight : null,
                  child: const Text('⟳ Rotate Right'),
                ),
                JuicyButton(
                  onPressed: controlsEnabled ? onMirror : null,
                  child: const Text('Mirror (M)'),
                ),
                JuicyButton(
                  onPressed: controlsEnabled && canHold ? onHold : null,
                  child: const Text('Hold (C)'),
                ),
                if (cfg.hasManualSpeedBoost)
                  JuicyButton(
                    onPressed: controlsEnabled && canSpeedUp ? onSpeedUp : null,
                    child: Text(
                      'Speed +${speedBoost * 20}%  Score x${(1 + speedBoost * 0.15).toStringAsFixed(2)}',
                    ),
                  ),
                if (cfg.hasCavityFiller)
                  JuicyButton(
                    onPressed: controlsEnabled && cavityCharges > 0
                        ? onFillCavities
                        : null,
                    child: Text('Fill Cavities (G)  x$cavityCharges'),
                  ),
              ],
            ),
            if (state == GameState.over) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: onRestart,
                    child: const Text('Play Again'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
