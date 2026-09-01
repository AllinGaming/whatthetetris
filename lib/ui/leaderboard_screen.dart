import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../models/coop_variant.dart';
import '../services/daily_challenge_service.dart';
import '../services/leaderboard_service.dart';
import 'widgets/neon_text.dart';

enum _LeaderboardBoard { classic, daily, multiplayer, multiplayerMirror }

/// Per-mode leaderboards (docs/GDD.md SS6.6), backed by [LeaderboardService].
/// Only a new local best is submitted, and Firestore rules limit direct writes
/// to the authenticated player's own increasing score (see firestore.rules).
/// Renders an offline state when Firebase Auth is unavailable.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.leaderboard});

  final LeaderboardService leaderboard;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  _LeaderboardBoard _selected = _LeaderboardBoard.classic;
  late Future<List<LeaderboardEntry>> _entries;

  static const _leaderboardBoards = _LeaderboardBoard.values;

  /// Daily Challenge scores live in their own per-day collection rather
  /// than the mode's all-time one (see [LeaderboardService.fetchTop]) --
  /// [GameScreen] already submits them this way, but until now nothing ever
  /// fetched them back, so a whole day's worth of daily submissions was
  /// effectively write-only.
  Future<List<LeaderboardEntry>> _fetch(
    _LeaderboardBoard board, {
    bool forceRefresh = false,
  }) {
    return switch (board) {
      _LeaderboardBoard.classic => widget.leaderboard.fetchTop(
        mode: GameMode.chill,
        forceRefresh: forceRefresh,
      ),
      _LeaderboardBoard.daily => widget.leaderboard.fetchTop(
        mode: GameMode.daily,
        isDaily: true,
        dailySeed: DailyChallengeService.seedForToday(),
        forceRefresh: forceRefresh,
      ),
      _LeaderboardBoard.multiplayer => widget.leaderboard.fetchTopMultiplayer(
        forceRefresh: forceRefresh,
      ),
      _LeaderboardBoard.multiplayerMirror =>
        widget.leaderboard.fetchTopMultiplayer(
          forceRefresh: forceRefresh,
          variant: CoopVariant.mirror,
        ),
    };
  }

  String _label(_LeaderboardBoard board) => switch (board) {
    _LeaderboardBoard.classic => 'Classic',
    _LeaderboardBoard.daily => 'Daily Challenge',
    _LeaderboardBoard.multiplayer => '2 Player',
    _LeaderboardBoard.multiplayerMirror => '2 Player Mirror',
  };

  @override
  void initState() {
    super.initState();
    _entries = _fetch(_selected);
  }

  void _selectBoard(_LeaderboardBoard board, {bool forceRefresh = false}) {
    setState(() {
      _selected = board;
      _entries = _fetch(board, forceRefresh: forceRefresh);
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _selectBoard(_selected, forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
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
                        _PlayerStatus(leaderboard: widget.leaderboard),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final board in _leaderboardBoards)
                              ChoiceChip(
                                label: Text(_label(board)),
                                selected: _selected == board,
                                onSelected: (_) => _selectBoard(board),
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
                                  final isYou = widget.leaderboard
                                      .isCurrentPlayer(entry.uid);
                                  return ListTile(
                                    leading: Text(
                                      '#${i + 1}',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    title: Text(
                                      isYou
                                          ? '${entry.name} (You)'
                                          : entry.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _selected ==
                                              _LeaderboardBoard
                                                  .multiplayerMirror
                                          ? 'Mirror shared-board best'
                                          : _selected ==
                                                _LeaderboardBoard.multiplayer
                                          ? 'Shared-board team best'
                                          : 'Level ${entry.level}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    trailing: Text(
                                      entry.score.toString(),
                                      style: TextStyle(
                                        color: isYou ? accent : Colors.white70,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
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

class _PlayerStatus extends StatelessWidget {
  const _PlayerStatus({required this.leaderboard});

  final LeaderboardService leaderboard;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      children: [
        Icon(
          leaderboard.currentPlayerIsAnonymous
              ? Icons.person_outline
              : Icons.verified_user_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                leaderboard.currentPlayerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                (leaderboard.currentPlayerIsAnonymous
                        ? 'Anonymous player '
                        : 'Logged-in player ') +
                    leaderboard.currentPlayerShortId,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
            "Leaderboards aren't available right now.",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            'Classic and Daily remain fully playable offline. An active '
            'Firebase player is required for online rankings and 2 Player.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
