import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/piece.dart';
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
    required this.onPauseOrPlay,
    required this.onMenu,
  });

  final GameState state;
  final int score;
  final int lines;
  final int level;
  final PieceDefinition upcoming;
  final VoidCallback onPauseOrPlay;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.4), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu, color: Colors.white70),
          ),
          _MiniStat(label: 'Score', value: score),
          _MiniStat(label: 'Lines', value: lines),
          _MiniStat(label: 'Lvl', value: level),
          const Spacer(),
          NextPiecePreview(piece: upcoming),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onPauseOrPlay,
            icon: Icon(
              state == GameState.paused ? Icons.play_arrow : Icons.pause,
              color: accent,
            ),
          ),
        ],
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
