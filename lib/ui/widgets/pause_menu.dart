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
        content: const Text('Your current progress on this run will be lost.'),
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
    return Positioned.fill(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF14161F).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: accent,
                    shadows: neonShadows(accent),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  modeLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MiniStat(label: 'Score', value: '$score'),
                    Container(width: 1, height: 28, color: Colors.white12),
                    _MiniStat(label: 'Level', value: '$level'),
                    Container(width: 1, height: 28, color: Colors.white12),
                    _MiniStat(label: 'Lines', value: '$lines'),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Resume'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmRestart(context),
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Restart'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _confirmQuit(context),
                  icon: const Icon(Icons.exit_to_app, size: 18),
                  label: const Text('Quit to Menu'),
                ),
              ],
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
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}
