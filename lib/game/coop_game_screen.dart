import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/piece.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/high_score_service.dart';
import '../services/leaderboard_service.dart';
import '../services/multiplayer_session_service.dart';
import '../services/theme_service.dart';
import '../ui/widgets/quick_mute_button.dart';
import 'coop_board_painter.dart';
import 'coop_game_engine.dart';

class CoopGameScreen extends StatefulWidget {
  const CoopGameScreen({
    super.key,
    required this.session,
    required this.theme,
    required this.analytics,
    required this.audio,
    required this.highScores,
    required this.leaderboard,
  });

  final MultiplayerSessionService session;
  final ThemeService theme;
  final AnalyticsService analytics;
  final AudioService audio;
  final HighScoreService highScores;
  final LeaderboardService leaderboard;

  @override
  State<CoopGameScreen> createState() => _CoopGameScreenState();
}

class _CoopGameScreenState extends State<CoopGameScreen> {
  static const _gravity = Duration(milliseconds: 650);

  final _focusNode = FocusNode();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  Timer? _timer;
  CoopGameEngine? _engine;
  CoopGameSnapshot? _snapshot;
  String? _networkError;
  DateTime? _roundStartedAt;
  int _roundNumber = 0;
  final Map<CoopAction, int> _actionCounts = {
    for (final action in CoopAction.values) action: 0,
  };

  CoopPlayer get _me => widget.session.player!;
  bool get _isHost => _me == CoopPlayer.red;

  @override
  void initState() {
    super.initState();
    unawaited(widget.audio.playMusic(MusicTrack.gameplay));
    unawaited(widget.analytics.screenViewed('multiplayer_game'));
    widget.highScores.addListener(_onHighScoreChanged);
    widget.session.addListener(_onConnectionChanged);
    _messageSubscription = widget.session.messages.listen(_onMessage);
    if (_isHost) {
      _startHostGame();
    } else {
      unawaited(widget.session.send({'type': 'ready'}));
    }
  }

  @override
  void dispose() {
    _endRound('left_game', _snapshot);
    _timer?.cancel();
    _messageSubscription?.cancel();
    widget.highScores.removeListener(_onHighScoreChanged);
    widget.session.removeListener(_onConnectionChanged);
    _focusNode.dispose();
    unawaited(widget.session.close());
    unawaited(widget.audio.playMusic(MusicTrack.menu));
    super.dispose();
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    if (widget.session.status == MultiplayerConnectionStatus.disconnected ||
        widget.session.status == MultiplayerConnectionStatus.failed) {
      _timer?.cancel();
      _endRound('connection_lost', _snapshot);
    }
    setState(() {});
  }

  void _onHighScoreChanged() {
    if (mounted) setState(() {});
  }

  void _startHostGame() {
    _timer?.cancel();
    _engine = CoopGameEngine(seed: DateTime.now().microsecondsSinceEpoch);
    _publishSnapshot();
    _timer = Timer.periodic(_gravity, (_) {
      final engine = _engine;
      if (engine == null || engine.gameOver) return;
      if (engine.tick()) _publishSnapshot();
    });
  }

  void _onMessage(Map<String, dynamic> message) {
    final type = message['type'];
    if (_isHost) {
      if (type == 'action') {
        final actionName = message['action'] as String?;
        final action = CoopAction.values.where(
          (value) => value.name == actionName,
        );
        if (action.isNotEmpty &&
            _engine?.applyAction(CoopPlayer.blue, action.first) == true) {
          if (action.first == CoopAction.fillCavity) {
            unawaited(
              widget.session.send({
                'type': 'actionAccepted',
                'action': CoopAction.fillCavity.name,
              }),
            );
          }
          _publishSnapshot();
        }
      } else if (type == 'ready') {
        _publishSnapshot();
      } else if (type == 'restart') {
        _startHostGame();
      }
      return;
    }
    if (type == 'actionAccepted' &&
        message['action'] == CoopAction.fillCavity.name) {
      unawaited(widget.audio.play(Sfx.cavityFill));
      unawaited(widget.analytics.cavityFillUsed());
      return;
    }
    if (type != 'snapshot' || message['state'] is! Map) return;
    try {
      final next = CoopGameSnapshot.fromJson(
        Map<String, dynamic>.from(message['state'] as Map<dynamic, dynamic>),
      );
      if (_snapshot == null || next.revision >= _snapshot!.revision) {
        _acceptSnapshot(next);
      }
    } catch (_) {
      setState(() => _networkError = 'Received an invalid board update.');
    }
  }

  void _publishSnapshot() {
    final engine = _engine;
    if (engine == null) return;
    final snapshot = engine.snapshot();
    _acceptSnapshot(snapshot);
    unawaited(
      widget.session
          .send({'type': 'snapshot', 'state': snapshot.toJson()})
          .catchError((_) {
            if (mounted) {
              setState(() => _networkError = 'Could not sync the board.');
            }
          }),
    );
  }

  void _act(CoopAction action) {
    if (_snapshot?.gameOver ?? true) return;
    _actionCounts[action] = (_actionCounts[action] ?? 0) + 1;
    if (_isHost) {
      if (_engine?.applyAction(CoopPlayer.red, action) == true) {
        if (action == CoopAction.fillCavity) {
          unawaited(widget.audio.play(Sfx.cavityFill));
          unawaited(widget.analytics.cavityFillUsed());
        }
        _publishSnapshot();
      }
    } else {
      unawaited(widget.session.send({'type': 'action', 'action': action.name}));
    }
  }

  void _restart() {
    unawaited(
      widget.analytics.multiplayerRestarted(
        role: _me.name,
        completedRounds: _roundNumber,
      ),
    );
    if (_isHost) {
      _startHostGame();
    } else {
      unawaited(widget.session.send({'type': 'restart'}));
    }
  }

  void _acceptSnapshot(CoopGameSnapshot next) {
    if (!mounted) return;
    final previous = _snapshot;
    if (previous == null || (previous.gameOver && !next.gameOver)) {
      _beginRound();
    }
    if (previous?.gameOver != true && next.gameOver) {
      if (_roundStartedAt == null) _beginRound();
      final isNewBest = next.score > widget.highScores.bestMultiplayerScore;
      unawaited(_recordHighScore(next, isNewBest: isNewBest));
      unawaited(widget.audio.play(isNewBest ? Sfx.newBest : Sfx.gameOver));
      _endRound('top_out', next);
    }
    setState(() {
      _snapshot = next;
      _networkError = null;
    });
  }

  Future<void> _recordHighScore(
    CoopGameSnapshot snapshot, {
    required bool isNewBest,
  }) async {
    if (snapshot.score <= 0) return;
    await widget.highScores.submitMultiplayerScore(snapshot.score);
    if (!isNewBest) return;
    await widget.leaderboard.submitMultiplayerScore(
      score: snapshot.score,
      level: 1 + snapshot.lines ~/ 10,
      isNewBest: true,
    );
  }

  void _beginRound() {
    _roundNumber++;
    _roundStartedAt = DateTime.now();
    for (final action in CoopAction.values) {
      _actionCounts[action] = 0;
    }
    unawaited(
      widget.analytics.multiplayerRoundStarted(
        role: _me.name,
        roundNumber: _roundNumber,
      ),
    );
  }

  void _endRound(String reason, CoopGameSnapshot? snapshot) {
    final startedAt = _roundStartedAt;
    if (startedAt == null) return;
    _roundStartedAt = null;
    unawaited(
      widget.analytics.multiplayerRoundEnded(
        role: _me.name,
        reason: reason,
        roundNumber: _roundNumber,
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
        score: snapshot?.score ?? 0,
        lines: snapshot?.lines ?? 0,
        moves:
            (_actionCounts[CoopAction.left] ?? 0) +
            (_actionCounts[CoopAction.right] ?? 0),
        rotations:
            (_actionCounts[CoopAction.rotateLeft] ?? 0) +
            (_actionCounts[CoopAction.rotateRight] ?? 0),
        softDrops: _actionCounts[CoopAction.softDrop] ?? 0,
        hardDrops: _actionCounts[CoopAction.hardDrop] ?? 0,
      ),
    );
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _act(CoopAction.left);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _act(CoopAction.right);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      _act(CoopAction.softDrop);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      _act(CoopAction.rotateRight);
    } else if (key == LogicalKeyboardKey.keyQ) {
      _act(CoopAction.rotateLeft);
    } else if (key == LogicalKeyboardKey.space) {
      _act(CoopAction.hardDrop);
    } else if (key == LogicalKeyboardKey.keyG) {
      _act(CoopAction.fillCavity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final connected = widget.session.connected;
    final meColor = _me == CoopPlayer.red ? duoBlColor : duoTrColor;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '2 Player · ${widget.session.roomCode}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          QuickMuteButton(audio: widget.audio, compact: true),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _PlayerBadge(player: _me, color: meColor),
            ),
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: SafeArea(
          child: Column(
            children: [
              _StatusBar(
                connected: connected,
                score: snapshot?.score ?? 0,
                lines: snapshot?.lines ?? 0,
                bestScore: widget.highScores.bestMultiplayerScore,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Center(
                    child: snapshot == null
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 14),
                              Text('Syncing the shared board…'),
                            ],
                          )
                        : AspectRatio(
                            aspectRatio: snapshot.cols / snapshot.rows,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(
                                  painter: CoopBoardPainter(
                                    board: snapshot.buildBoard(),
                                    config: snapshot.config,
                                    redPiece: snapshot.activeFor(
                                      CoopPlayer.red,
                                    ),
                                    bluePiece: snapshot.activeFor(
                                      CoopPlayer.blue,
                                    ),
                                    localGhost: snapshot.ghostFor(_me),
                                    localPlayer: _me,
                                    revision: snapshot.revision,
                                    theme: widget.theme.current,
                                  ),
                                ),
                                if (snapshot.gameOver)
                                  _GameOverOverlay(onRestart: _restart),
                                if (!connected) const _DisconnectedOverlay(),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              if (_networkError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _networkError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Red owns ◢ · Blue owns ◥ · First to complete a line earns its fill',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              _CoopControls(
                enabled: connected && snapshot != null && !snapshot.gameOver,
                cavityCharges: snapshot?.cavityChargesFor(_me) ?? 0,
                onAction: _act,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({required this.player, required this.color});

  final CoopPlayer player;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      border: Border.all(color: color.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'YOU: ${player.name.toUpperCase()}',
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
    ),
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.connected,
    required this.score,
    required this.lines,
    required this.bestScore,
  });

  final bool connected;
  final int score;
  final int lines;
  final int bestScore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: [
        Icon(
          connected ? Icons.link : Icons.link_off,
          size: 18,
          color: connected ? Colors.greenAccent : Colors.orangeAccent,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(connected ? 'Peer connected' : 'Connection lost')),
        Text(
          'Score $score  ·  Lines $lines\nBest $bestScore',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class _CoopControls extends StatelessWidget {
  const _CoopControls({
    required this.enabled,
    required this.cavityCharges,
    required this.onAction,
  });

  final bool enabled;
  final int cavityCharges;
  final ValueChanged<CoopAction> onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _button(Icons.arrow_back, 'Left', CoopAction.left),
        _button(Icons.rotate_left, 'Rotate L', CoopAction.rotateLeft),
        _button(Icons.arrow_downward, 'Down', CoopAction.softDrop),
        _button(Icons.rotate_right, 'Rotate R', CoopAction.rotateRight),
        _button(Icons.arrow_forward, 'Right', CoopAction.right),
        _button(Icons.vertical_align_bottom, 'Drop', CoopAction.hardDrop),
        Tooltip(
          message: 'Fill the lowest cavity (G)',
          child: FilledButton.tonalIcon(
            onPressed: enabled && cavityCharges > 0
                ? () => onAction(CoopAction.fillCavity)
                : null,
            icon: const Icon(Icons.auto_fix_high, size: 20),
            label: Text('Fill x$cavityCharges'),
          ),
        ),
      ],
    ),
  );

  Widget _button(IconData icon, String label, CoopAction action) =>
      FilledButton.tonalIcon(
        onPressed: enabled ? () => onAction(action) : null,
        icon: Icon(icon, size: 20),
        label: Text(label),
      );
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.onRestart});

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.68),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TEAM GAME OVER',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.replay),
            label: const Text('Play Again'),
          ),
        ],
      ),
    ),
  );
}

class _DisconnectedOverlay extends StatelessWidget {
  const _DisconnectedOverlay();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.72),
    child: const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'The other player disconnected. Return to the lobby to make a new room.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}
