import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_screen.dart';
import '../game/tutorial_level_screen.dart';
import '../models/game_mode.dart';
import '../models/piece.dart';
import '../models/pieces.dart';
import '../services/audio_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/high_score_service.dart';
import '../services/live_services.dart';
import '../services/settings_service.dart';
import '../services/stats_service.dart';
import '../services/theme_service.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';
import 'widgets/fusion_hero.dart';
import 'widgets/menu_backdrop.dart';
import 'widgets/neon_text.dart';
import 'widgets/next_piece_preview.dart';

const _categoryOrder = [
  ModeCategory.marathon,
  ModeCategory.timed,
  ModeCategory.practice,
  ModeCategory.daily,
];

const _categoryLabels = {
  ModeCategory.marathon: 'Marathon',
  ModeCategory.timed: 'Timed',
  ModeCategory.practice: 'Practice',
  ModeCategory.daily: 'Daily',
};

/// Trimmed from the mode-select roster per player feedback — kept in
/// [GameMode]/[GameModeConfig] rather than deleted, so they're a one-line
/// change away from coming back.
const _hiddenModes = {GameMode.arcade, GameMode.sprint, GameMode.zen};

/// Ties each mode's card to one of its own piece colors — a "tetrisy" per-
/// mode identity for the accent bar/swatch, rather than every card looking
/// identical apart from its text. [GameMode.daily] deliberately has no
/// entry: as the one special, non-marathon/timed/practice mode, it uses the
/// theme's own accent color instead of borrowing a piece's.
const _modeAccentPiece = {
  GameMode.chill: 'I4',
  GameMode.classic: 'O4',
  GameMode.arcade: 'Z4',
  GameMode.sprint: 'S4',
  GameMode.ultra: 'L4',
  GameMode.zen: 'J4',
};

class StartScreen extends StatelessWidget {
  const StartScreen({
    super.key,
    required this.highScores,
    required this.audio,
    required this.settings,
    required this.theme,
    required this.stats,
    required this.dailyChallenge,
    required this.live,
  });

  final HighScoreService highScores;
  final AudioService audio;
  final SettingsService settings;
  final ThemeService theme;
  final StatsService stats;
  final DailyChallengeService dailyChallenge;
  final LiveServices live;

  Future<void> _showTutorial(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TutorialLevelScreen(settings: settings),
      ),
    );
    unawaited(settings.setHasSeenTutorial(true));
  }

  /// Random strips out the only signal Duo gives for free (which triangle
  /// half a cell still needs), so switching to it is a real difficulty
  /// jump, not just a cosmetic pick — worth a confirm rather than a
  /// one-tap accident.
  Future<void> _confirmRandomColorMode(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch to Random colors?'),
        content: const Text(
          "This makes the game visually much harder to play — color won't "
          'tell you anything about a piece\'s shape or which triangle half '
          'it needs anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await settings.setPieceColorMode(PieceColorMode.random);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: Listenable.merge([highScores, dailyChallenge, settings]),
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            MenuBackdrop(
              theme: theme.current,
              reduceMotion: settings.reduceMotion,
            ),
            SafeArea(
              bottom: false,
              // SingleChildScrollView outside Center (not the other way
              // around) so its hit-testable width is the full screen --
              // otherwise it only sizes itself to its centered, width-capped
              // content, leaving dead margins on wider screens where a drag
              // silently does nothing instead of scrolling.
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Fills wide (desktop/web) viewports instead of
                      // sitting as a narrow column with dead space on
                      // either side, while staying phone-shaped on small
                      // screens.
                      maxWidth: math.min(
                        MediaQuery.sizeOf(context).width * 0.92,
                        900,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FusionHero(
                            colorA: theme.current.colorFor('T4'),
                            colorB: theme.current.colorFor('S4'),
                            reduceMotion: settings.reduceMotion,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'What The Tetris',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  shadows: neonShadows(accent),
                                ),
                          ),
                          const SizedBox(height: 14),
                          _MenuToolbar(
                            accent: accent,
                            items: [
                              _ToolbarItem(
                                icon: Icons.school_outlined,
                                tooltip: 'How to Play',
                                onPressed: () => _showTutorial(context),
                              ),
                              _ToolbarItem(
                                icon: Icons.emoji_events_outlined,
                                tooltip: 'Stats & Achievements',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AchievementsScreen(
                                      stats: stats,
                                      highScores: highScores,
                                      dailyChallenge: dailyChallenge,
                                    ),
                                  ),
                                ),
                              ),
                              _ToolbarItem(
                                icon: Icons.leaderboard_outlined,
                                tooltip: 'Leaderboards',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LeaderboardScreen(
                                      leaderboard: live.leaderboard,
                                    ),
                                  ),
                                ),
                              ),
                              _ToolbarItem(
                                icon: Icons.star_outline,
                                tooltip: 'VIP Pass',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PaywallScreen(
                                      purchases: live.purchases,
                                    ),
                                  ),
                                ),
                              ),
                              _ToolbarItem(
                                icon: Icons.settings,
                                tooltip: 'Settings',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SettingsScreen(
                                      audio: audio,
                                      settings: settings,
                                      theme: theme,
                                      live: live,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Triangle-half Tetris. Pick a mode to start.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                          _CategoryHeader(
                            label: 'Piece Colors',
                            accent: accent,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ColorModeChip(
                                label: 'Duo',
                                badge: 'Recommended',
                                color: accent,
                                selected:
                                    settings.pieceColorMode ==
                                    PieceColorMode.duo,
                                onTap: () => unawaited(
                                  settings.setPieceColorMode(
                                    PieceColorMode.duo,
                                  ),
                                ),
                              ),
                              _ColorModeChip(
                                label: 'Random',
                                color: Colors.pinkAccent,
                                selected:
                                    settings.pieceColorMode ==
                                    PieceColorMode.random,
                                onTap: () => _confirmRandomColorMode(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          for (final category in _categoryOrder)
                            if (GameMode.values.any(
                              (m) =>
                                  m.config.category == category &&
                                  !_hiddenModes.contains(m),
                            )) ...[
                              _CategoryHeader(
                                label: _categoryLabels[category]!,
                                accent: accent,
                              ),
                              const SizedBox(height: 10),
                              for (final mode in GameMode.values.where(
                                (m) =>
                                    m.config.category == category &&
                                    !_hiddenModes.contains(m),
                              )) ...[
                                _ModeCard(
                                  mode: mode,
                                  highScores: highScores,
                                  audio: audio,
                                  settings: settings,
                                  theme: theme,
                                  stats: stats,
                                  dailyChallenge: dailyChallenge,
                                  live: live,
                                ),
                                const SizedBox(height: 12),
                              ],
                              const SizedBox(height: 12),
                            ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarItem {
  const _ToolbarItem({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// The secondary-nav row (tutorial/achievements/leaderboard/VIP/settings),
/// grouped into one translucent pill rather than loose icons floating on
/// the backdrop — reads as a single toolbar, and wraps to a second line
/// instead of overflowing on narrow screens.
class _MenuToolbar extends StatelessWidget {
  const _MenuToolbar({required this.items, required this.accent});

  final List<_ToolbarItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final item in items)
              IconButton(
                onPressed: item.onPressed,
                icon: Icon(item.icon, size: 20),
                tooltip: item.tooltip,
                color: Colors.white70,
                hoverColor: accent.withValues(alpha: 0.12),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: accent,
            letterSpacing: 1.4,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: accent.withValues(alpha: 0.18)),
        ),
      ],
    );
  }
}

/// A selectable pill for [PieceColorMode] — surfaced right on the mode-select
/// screen (in addition to the Settings dropdown) so it's picked as easily
/// and visibly as a game mode, rather than buried three taps deep.
class _ColorModeChip extends StatelessWidget {
  const _ColorModeChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  /// A short tag rendered after the label (e.g. "Recommended") -- optional,
  /// for calling out the easiest/default choice among otherwise-equal pills.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: badge == null
          ? '$label piece colors'
          : '$label piece colors, $badge',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : Colors.white24,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
              if (selected) ...[
                const SizedBox(width: 5),
                Icon(Icons.check, size: 14, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.highScores,
    required this.audio,
    required this.settings,
    required this.theme,
    required this.stats,
    required this.dailyChallenge,
    required this.live,
  });

  final GameMode mode;
  final HighScoreService highScores;
  final AudioService audio;
  final SettingsService settings;
  final ThemeService theme;
  final StatsService stats;
  final DailyChallengeService dailyChallenge;
  final LiveServices live;

  bool get _isDaily => mode == GameMode.daily;

  void _play(BuildContext context) {
    unawaited(live.analytics.modeSelected(mode));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: mode,
          highScores: highScores,
          audio: audio,
          settings: settings,
          theme: theme,
          stats: stats,
          dailyChallenge: dailyChallenge,
          live: live,
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    if (_isDaily && dailyChallenge.playedToday) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("You've already played today"),
          content: Text(
            '${dailyChallenge.todaysCleared ? "You cleared today's board! 🎉\n" : ''}'
            "Today's score: ${dailyChallenge.todaysScore ?? 0}\n"
            'Streak: ${dailyChallenge.currentStreak} day'
            '${dailyChallenge.currentStreak == 1 ? '' : 's'}\n'
            'Come back tomorrow for a new board.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    _play(context);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = mode.config;
    final themeAccent = Theme.of(context).colorScheme.primary;
    final accentPieceName = _modeAccentPiece[mode];
    // Each mode borrows one of its own piece's colors for its card — a
    // "tetrisy" per-mode identity instead of every card looking identical.
    // Daily has no single representative piece, so it keeps the app's own
    // accent, matching its special (not marathon/timed/practice) status.
    final accent = accentPieceName != null
        ? theme.current.colorFor(accentPieceName)
        : themeAccent;
    final accentPiece = accentPieceName != null
        ? Pieces.all.firstWhere((p) => p.name == accentPieceName)
        : null;
    final bestTime = highScores.bestTimeMs(mode);
    final alreadyPlayedToday = _isDaily && dailyChallenge.playedToday;
    final statLine = alreadyPlayedToday
        ? (dailyChallenge.todaysCleared
              ? 'Cleared! Score: ${dailyChallenge.todaysScore ?? 0} · come back tomorrow'
              : "Today's score: ${dailyChallenge.todaysScore ?? 0} · come back tomorrow")
        : cfg.lineTarget != null && bestTime != null
        ? 'Best time: ${_formatMs(bestTime)}'
        : 'Best score: ${highScores.bestScore(mode)}   ·   Best level: ${highScores.bestLevel(mode)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onTap(context),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        if (accentPiece != null) ...[
                          NextPiecePreview(
                            piece: accentPiece,
                            size: 44,
                            semanticLabel: '${cfg.label} piece',
                            // Any non-duo mode renders colorOverride
                            // uniformly -- this card swatch always wants a
                            // single solid color regardless of the
                            // player's actual piece-color-mode setting.
                            colorMode: PieceColorMode.random,
                            colorOverride: accent,
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      cfg.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  if (_isDaily &&
                                      dailyChallenge.currentStreak > 0) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orangeAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${dailyChallenge.currentStreak}',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cfg.description,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                statLine,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          alreadyPlayedToday
                              ? Icons.check_circle
                              : Icons.play_circle_fill,
                          size: 36,
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
