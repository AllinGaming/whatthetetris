import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../services/daily_challenge_service.dart';
import '../services/leaderboard_service.dart';
import 'widgets/neon_text.dart';

/// Per-mode leaderboards (docs/GDD.md SS6.6), backed by [LeaderboardService]
/// — scores only ever reach Firestore via the server-side `submitScore`
/// Cloud Function, never a direct client write (see firestore.rules).
/// Renders an honest "not available yet" state rather than an empty/broken
/// screen when live services aren't configured.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.leaderboard});

  final LeaderboardService leaderboard;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  GameMode _selected = GameMode.classic;
  late Future<List<LeaderboardEntry>> _entries;

  static const _leaderboardModes = [
    GameMode.chill,
    GameMode.classic,
    GameMode.arcade,
    GameMode.sprint,
    GameMode.ultra,
    GameMode.daily,
  ];

  /// Daily Challenge scores live in their own per-day collection rather
  /// than the mode's all-time one (see [LeaderboardService.fetchTop]) --
  /// [GameScreen] already submits them this way, but until now nothing ever
  /// fetched them back, so a whole day's worth of daily submissions was
  /// effectively write-only.
  Future<List<LeaderboardEntry>> _fetch(GameMode mode) {
    if (mode == GameMode.daily) {
      return widget.leaderboard.fetchTop(
        mode: mode,
        isDaily: true,
        dailySeed: DailyChallengeService.seedForToday(),
      );
    }
    return widget.leaderboard.fetchTop(mode: mode);
  }

  @override
  void initState() {
    super.initState();
    _entries = _fetch(_selected);
  }

  void _selectMode(GameMode mode) {
    setState(() {
      _selected = mode;
      _entries = _fetch(mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Leaderboards',
          style: TextStyle(shadows: neonShadows(accent, intensity: 0.6)),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: !widget.leaderboard.available
                ? const _NotAvailableYet()
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final mode in _leaderboardModes)
                              ChoiceChip(
                                label: Text(mode.config.label),
                                selected: _selected == mode,
                                onSelected: (_) => _selectMode(mode),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: FutureBuilder<List<LeaderboardEntry>>(
                            future: _entries,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final entries = snapshot.data ?? const [];
                              if (entries.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No scores yet for this mode.',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                );
                              }
                              return ListView.separated(
                                itemCount: entries.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(color: Colors.white12),
                                itemBuilder: (context, i) {
                                  final entry = entries[i];
                                  return ListTile(
                                    leading: Text(
                                      '#${i + 1}',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    title: Text(
                                      entry.score.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: Text(
                                      'Lvl ${entry.level}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
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

class _NotAvailableYet extends StatelessWidget {
  const _NotAvailableYet();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 48, color: Colors.white38),
          SizedBox(height: 16),
          Text(
            "Leaderboards aren't available yet.",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            'Every mode is still fully playable in the meantime — this '
            'screen will come alive once live services are configured.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
