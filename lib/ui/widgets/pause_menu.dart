import 'package:flutter/material.dart';

import 'neon_text.dart';

/// The pause overlay — a real menu instead of a bare dimmed "Paused" label.
/// Rendered as a widget on top of the board (not a [showDialog]), since
/// pause is toggled frequently via a single key press and a modal route
/// would fight with that rhythm.
class PauseMenu extends StatelessWidget {
  const PauseMenu({
    super.key,
    required this.modeLabel,
    required this.score,
    required this.level,
    required this.lines,
    required this.onResume,
    required this.onRestart,
    required this.onSettings,
    required this.onQuit,
  });

  final String modeLabel;
  final int score;
  final int level;
  final int lines;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onSettings;
  final VoidCallback onQuit;

  Future<void> _confirmRestart(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restart run?'),
        content: const Text('Your current progress on this run will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed == true) onRestart();
  }

  Future<void> _confirmQuit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quit to menu?'),
        content: const Text(
          'This ends the run — your score and stats so far will be saved, '
          'same as a normal game over.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (confirmed == true) onQuit();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // A fixed 280px cap left small phones with a card that was a needlessly
    // small fraction of the screen -- scale with viewport width instead (up
    // to a higher cap), so it actually reads as bigger on small screens
    // instead of just floating in the middle of unused space.
    final maxWidth = (screenWidth * 0.86).clamp(280.0, 340.0);
    return Positioned.fill(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          // A quick pop-in rather than snapping straight to full size —
          // TweenAnimationBuilder replays this from scratch every time a
          // fresh PauseMenu widget mounts (every pause), which is exactly
          // the "just appeared" moment it should play for.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF14161F).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PAUSED',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: accent,
                      shadows: neonShadows(accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modeLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MiniStat(label: 'Score', value: '$score'),
                      Container(width: 1, height: 32, color: Colors.white12),
                      _MiniStat(label: 'Level', value: '$level'),
                      Container(width: 1, height: 32, color: Colors.white12),
                      _MiniStat(label: 'Lines', value: '$lines'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow, size: 22),
                      label: const Text('Resume'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmRestart(context),
                      icon: const Icon(Icons.replay, size: 20),
                      label: const Text('Restart'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: onSettings,
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      label: const Text('Settings'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _confirmQuit(context),
                    icon: const Icon(Icons.exit_to_app, size: 20),
                    label: const Text('Quit to Menu'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
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
            fontSize: 17,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
