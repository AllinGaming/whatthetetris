import 'package:flutter/material.dart';

import '../game/game_animations.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/theme_palette.dart';
import 'widgets/next_piece_preview.dart';

/// Compact score/lines/level + next-piece strip for the portrait mobile
/// layout — the side panel's long mode description doesn't fit here, so
/// this is a peer widget rather than a resized [GameSidePanel].
class MobileStatsBar extends StatelessWidget {
  const MobileStatsBar({
    super.key,
    required this.state,
    required this.score,
    required this.lines,
    required this.level,
    required this.upcoming,
    required this.upcomingColor,
    required this.theme,
    required this.colorMode,
    required this.anim,
    this.modeClock,
    required this.onPauseOrPlay,
    required this.onMenu,
    required this.onShare,
  });

  final GameState state;
  final int score;
  final int lines;
  final int level;
  final List<PieceDefinition> upcoming;
  final Color? upcomingColor;
  final ThemePalette theme;
  final PieceColorMode colorMode;

  /// Drives the same danger/combo signals the board already shows, so the
  /// mobile HUD (which has no room for the board's own border pulse once
  /// the board itself is on screen above it) still carries that feedback.
  final GameAnimations anim;
  final String? modeClock;
  final VoidCallback onPauseOrPlay;
  final VoidCallback onMenu;
  final VoidCallback onShare;

  /// Danger (crisp red, board-matching) takes priority over combo heat
  /// (accent-to-red glow) since both would otherwise fight for the same
  /// thin top border.
  Color _borderColor(Color accent) {
    if (state == GameState.playing && anim.danger.value > 0) {
      final pulse = anim.danger.value;
      return Colors.redAccent.withValues(alpha: 0.35 + pulse * 0.45);
    }
    if (anim.comboHeat > 0) {
      final glow = Color.lerp(accent, Colors.redAccent, anim.comboHeat)!;
      final pulse = 0.5 + 0.5 * anim.comboPulse.value;
      return glow.withValues(alpha: 0.3 + 0.35 * pulse * anim.comboHeat);
    }
    return accent.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      // Only the two signals _borderColor reads, not anim.repaint's full
      // 9-controller merge — this bar has no other reason to rebuild on
      // every particle-physics/shake/flash tick.
      animation: Listenable.merge([anim.danger, anim.comboPulse]),
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          border: Border(
            top: BorderSide(color: _borderColor(accent), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu, color: Colors.white70),
              tooltip: 'Menu',
            ),
            _MiniStat(label: 'Score', value: score),
            _MiniStat(label: 'Lines', value: lines),
            _MiniStat(label: 'Lvl', value: level),
            if (modeClock != null) ...[
              const SizedBox(width: 6),
              Text(
                modeClock!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
            const Spacer(),
            if (state == GameState.over)
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.share, color: Colors.white70),
                tooltip: 'Share result',
              )
            else if (upcoming.isNotEmpty)
              NextPiecePreview(
                piece: upcoming.first,
                size: 52,
                colorMode: colorMode,
                colorOverride: upcomingColor,
              ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onPauseOrPlay,
              icon: Icon(
                state == GameState.paused ? Icons.play_arrow : Icons.pause,
                color: accent,
              ),
              tooltip: switch (state) {
                GameState.playing => 'Pause',
                GameState.paused => 'Resume',
                GameState.over => 'Play again',
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder: (context, v, _) => Text(
              '$v',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
