import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/active_piece.dart';
import '../models/coop_variant.dart';
import '../models/piece.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/high_score_service.dart';
import '../services/leaderboard_service.dart';
import '../services/multiplayer_session_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../ui/widgets/coop_score_hud.dart';
import '../ui/widgets/floating_toast.dart';
import '../ui/widgets/quick_mute_button.dart';
import 'coop_board_painter.dart';
import 'coop_effect_presentation.dart';
import 'coop_game_engine.dart';
import 'game_animations.dart';
import 'puzzle_speed_bonus.dart';

class _PendingCoopEffect {
  const _PendingCoopEffect(this.snapshot, this.effect);

  final CoopGameSnapshot snapshot;
  final CoopEffectState effect;
}

class CoopGameScreen extends StatefulWidget {
  const CoopGameScreen({
    super.key,
    required this.session,
    required this.theme,
    required this.analytics,
    required this.audio,
    required this.settings,
    required this.highScores,
    required this.leaderboard,
  });

  final MultiplayerSessionService session;
  final ThemeService theme;
  final AnalyticsService analytics;
  final AudioService audio;
  final SettingsService settings;
  final HighScoreService highScores;
  final LeaderboardService leaderboard;

  @override
  State<CoopGameScreen> createState() => _CoopGameScreenState();
}

class _CoopGameScreenState extends State<CoopGameScreen>
    with TickerProviderStateMixin {
  static const _gravity = Duration(milliseconds: 650);

  final _focusNode = FocusNode();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  Timer? _timer;
  Timer? _effectPlaybackTimer;
  final Queue<_PendingCoopEffect> _pendingEffects = Queue();
  CoopGameEngine? _engine;
  CoopGameSnapshot? _snapshot;
  late final GameAnimations _anim = GameAnimations(vsync: this)
    ..reduceMotion = widget.settings.reduceMotion;
  List<int> _effectCells = const [];
  List<int> _clearingRows = const [];
  final Map<int, ToastData> _toasts = {};
  int _toastId = 0;
  bool _roundWasNewBest = false;
  String? _networkError;
  DateTime? _roundStartedAt;
  int _roundNumber = 0;
  int _hostRoundId = 0;
  final Map<CoopAction, int> _actionCounts = {
    for (final action in CoopAction.values) action: 0,
  };

  CoopPlayer get _me => widget.session.player!;
  bool get _isHost => _me == CoopPlayer.red;

  @override
  void initState() {
    super.initState();
    _anim.lockFlash.duration = const Duration(milliseconds: 260);
    _anim.lineClear.duration = const Duration(milliseconds: 480);
    _anim.impactRing.duration = const Duration(milliseconds: 620);
    unawaited(widget.audio.playMusic(MusicTrack.gameplay));
    unawaited(widget.analytics.screenViewed('multiplayer_game'));
    widget.highScores.addListener(_onHighScoreChanged);
    widget.settings.addListener(_onSettingsChanged);
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
    _effectPlaybackTimer?.cancel();
    _messageSubscription?.cancel();
    widget.highScores.removeListener(_onHighScoreChanged);
    widget.settings.removeListener(_onSettingsChanged);
    widget.session.removeListener(_onConnectionChanged);
    _focusNode.dispose();
    _anim.dispose();
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

  void _onSettingsChanged() {
    _anim.reduceMotion = widget.settings.reduceMotion;
  }

  void _startHostGame() {
    _timer?.cancel();
    _engine = CoopGameEngine(
      seed: DateTime.now().microsecondsSinceEpoch,
      variant: widget.session.variant,
      roundId: ++_hostRoundId,
    );
    _publishSnapshot();
    _timer = Timer.periodic(_gravity, (_) {
      final engine = _engine;
      if (engine == null || engine.roundOver) return;
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
          unawaited(
            widget.session.send({
              'type': 'actionAccepted',
              'action': action.first.name,
            }),
          );
          _publishSnapshot();
        }
      } else if (type == 'ready') {
        _publishSnapshot();
      }
      return;
    }
    if (type == 'actionAccepted') {
      final actionName = message['action'] as String?;
      final actions = CoopAction.values.where(
        (value) => value.name == actionName,
      );
      if (actions.isNotEmpty) _playAcceptedAction(actions.first);
      return;
    }
    if (type != 'snapshot' || message['state'] is! Map) return;
    try {
      final next = CoopGameSnapshot.fromJson(
        Map<String, dynamic>.from(message['state'] as Map<dynamic, dynamic>),
      );
      if (_snapshot == null || next.isAtLeastAsNewAs(_snapshot!)) {
        _acceptSnapshot(next);
      }
    } catch (_) {
      setState(() => _networkError = 'Received an invalid board update.');
    }
  }

  void _publishSnapshot() {
    final engine = _engine;
    if (engine == null) return;
    if (engine.puzzleCleared && !engine.puzzleSpeedBonusAwarded) {
      final startedAt = _roundStartedAt;
      engine.awardPuzzleSpeedBonus(
        startedAt == null
            ? Duration.zero
            : DateTime.now().difference(startedAt),
      );
    }
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
    if (_snapshot?.roundOver ?? true) return;
    _actionCounts[action] = (_actionCounts[action] ?? 0) + 1;
    if (_isHost) {
      if (_engine?.applyAction(CoopPlayer.red, action) == true) {
        _playAcceptedAction(action);
        _publishSnapshot();
      }
    } else {
      unawaited(widget.session.send({'type': 'action', 'action': action.name}));
    }
  }

  void _restart() {
    if (!_isHost) return;
    unawaited(widget.audio.play(Sfx.menuTap));
    unawaited(
      widget.analytics.multiplayerRestarted(
        role: _me.name,
        completedRounds: _roundNumber,
        variant: widget.session.variant.analyticsName,
      ),
    );
    _startHostGame();
  }

  void _acceptSnapshot(CoopGameSnapshot next) {
    if (!mounted) return;
    final previous = _snapshot;
    final isNewRound = previous == null || next.roundId > previous.roundId;
    if (isNewRound) {
      _beginRound();
    }
    if (previous != null && next.roundId == previous.roundId) {
      _playMirrorChanges(previous, next);
      if (next.locks > previous.locks) {
        unawaited(widget.audio.play(Sfx.lock));
      }
      if (next.fusions > previous.fusions) {
        unawaited(widget.audio.play(Sfx.fusionBonus));
      }
      final cleared = next.lines - previous.lines;
      if (cleared > 0) {
        unawaited(widget.audio.play(_clearSfx(cleared)));
      }
      if (next.lines ~/ 10 > previous.lines ~/ 10) {
        unawaited(widget.audio.play(Sfx.levelUp));
      }
      final previousEffectId = previous.effects.isEmpty
          ? previous.effect?.id ?? 0
          : previous.effects.last.id;
      for (final effect in next.effects.where(
        (effect) => effect.id > previousEffectId,
      )) {
        _queueEffect(next, effect);
      }
      if (next.lines ~/ 10 > previous.lines ~/ 10) {
        _showToast(
          'TEAM LEVEL ${1 + next.lines ~/ 10}!',
          widget.theme.current.accent,
        );
        _anim.triggerLevelUp();
      }
    }
    final roundJustEnded =
        next.roundOver &&
        (previous == null ||
            next.roundId > previous.roundId ||
            !previous.roundOver);
    if (roundJustEnded) {
      if (_roundStartedAt == null) _beginRound();
      final isNewBest =
          next.score >
          widget.highScores.bestMultiplayerScoreFor(widget.session.variant);
      _roundWasNewBest = isNewBest;
      unawaited(_recordHighScore(next, isNewBest: isNewBest));
      if (next.puzzleCleared) {
        unawaited(widget.audio.play(Sfx.levelUp));
        _showToastData(
          ToastData(
            'PUZZLE CLEARED!',
            Colors.greenAccent,
            big: true,
            subtitle: 'SPEED BONUS +${next.puzzleSpeedBonus}',
            duration: const Duration(milliseconds: 2600),
            backdrop: true,
          ),
        );
        _anim.triggerCelebration();
        for (var col = 0; col < next.cols; col += 2) {
          _burst(Offset(col + 0.5, 1), Colors.greenAccent, count: 8);
        }
      } else {
        unawaited(widget.audio.play(Sfx.gameOver));
      }
      if (isNewBest) {
        _showToast('NEW TEAM BEST!', Colors.amberAccent, big: true);
        if (!next.puzzleCleared) {
          _anim.triggerCelebration();
          for (var col = 0; col < next.cols; col += 2) {
            _burst(Offset(col + 0.5, 1), Colors.amberAccent, count: 8);
          }
        }
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 220),
            () => widget.audio.play(Sfx.newBest),
          ),
        );
      }
      _endRound(next.puzzleCleared ? 'puzzle_cleared' : 'top_out', next);
    }
    setState(() {
      _snapshot = next;
      _networkError = null;
    });
    _anim.setComboHeat((next.combo / 6).clamp(0.0, 1.0));
    _anim.setDanger(_isDanger(next));
  }

  void _queueEffect(CoopGameSnapshot snapshot, CoopEffectState effect) {
    _pendingEffects.add(_PendingCoopEffect(snapshot, effect));
    _playNextEffect();
  }

  void _playNextEffect() {
    if (!mounted || _effectPlaybackTimer != null || _pendingEffects.isEmpty) {
      return;
    }
    final pending = _pendingEffects.removeFirst();
    _playEffect(pending.snapshot, pending.effect);
    _effectPlaybackTimer = Timer(const Duration(milliseconds: 260), () {
      _effectPlaybackTimer = null;
      _playNextEffect();
    });
  }

  void _playEffect(CoopGameSnapshot next, CoopEffectState effect) {
    final playerColor = effect.player.color;
    _effectCells = effect.cellIndexes;
    _anim.lockFlash.forward(from: 0);
    final effectCenter = _cellIndexesCenter(next, effect.cellIndexes);
    for (final index in effect.cellIndexes) {
      final row = index ~/ next.cols;
      final col = index % next.cols;
      if (row < 0 || row >= next.rows) continue;
      _burst(
        Offset(col + 0.5, row + 0.5),
        effect.fusionCount > 0 ? const Color(0xFFFFD24C) : playerColor,
        count: effect.fusionCount > 0 ? 5 : 2,
      );
    }
    if (effectCenter != null) {
      // The white core keeps either player's effect visible over red, blue,
      // or already-fused cells without multiplying every per-cell burst.
      _burst(effectCenter, Colors.white, count: effect.fusionCount > 0 ? 6 : 3);
    }

    if (effect.hardDropDistance >= 3 && effectCenter != null) {
      _anim.triggerImpactRing(effectCenter, color: playerColor);
      _anim.triggerShake(
        intensity: (0.45 + effect.hardDropDistance / 14).clamp(0.45, 1.25),
      );
    }

    if (effect.fusionCount > 0) {
      unawaited(widget.analytics.fusionBonus(effect.fusionCount));
    }

    if (effect.lineCount > 0) {
      _clearingRows = effect.clearedRows;
      unawaited(
        _anim.lineClear.forward(from: 0).whenComplete(() {
          if (mounted && _clearingRows == effect.clearedRows) {
            setState(() => _clearingRows = const []);
          }
        }),
      );
      for (final row in effect.clearedRows) {
        for (var col = 0; col < next.cols; col++) {
          _burst(
            Offset(col + 0.5, row + 0.5),
            Color.lerp(duoBlColor, duoTrColor, col / (next.cols - 1))!,
            count: 3,
          );
        }
      }
      if (effect.lineCount >= 2) {
        _anim.triggerShake(intensity: effect.lineCount >= 4 ? 1.6 : 1.0);
      }
      if (effect.comboCount > 1) {
        unawaited(widget.audio.play(Sfx.comboTick));
        unawaited(widget.analytics.combo(effect.comboCount));
      }
      unawaited(widget.analytics.lineClear(effect.lineCount));
      unawaited(_haptic(HapticFeedback.heavyImpact));
    }

    final callout = buildCoopEffectCallout(
      effect,
      themeAccent: widget.theme.current.accent,
    );
    if (callout != null) _showToastData(callout);
  }

  void _playMirrorChanges(CoopGameSnapshot previous, CoopGameSnapshot next) {
    if (!widget.session.variant.allowsMirror) return;
    for (final player in CoopPlayer.values) {
      final before = previous.activeFor(player);
      final after = next.activeFor(player);
      if (before == null ||
          after == null ||
          before.mirrored == after.mirrored) {
        continue;
      }
      final center = _pieceCenter(after);
      _burst(center, player.color, count: 8);
      _anim.triggerImpactRing(center, color: player.color);
      unawaited(widget.audio.play(Sfx.mirror));
      if (player == _me) {
        unawaited(_haptic(HapticFeedback.mediumImpact));
      }
    }
  }

  void _burst(Offset origin, Color color, {int count = 12}) {
    _anim.burst(
      origin,
      color,
      count: count,
      lifeScale: 1.65,
      fadeFraction: 0.55,
    );
  }

  Offset _pieceCenter(ActivePiece piece) {
    final cells = piece.cellsOnBoard();
    final dx = cells.fold<double>(0, (sum, cell) => sum + cell.col + 0.5);
    final dy = cells.fold<double>(0, (sum, cell) => sum + cell.row + 0.5);
    return Offset(dx / cells.length, dy / cells.length);
  }

  Offset? _cellIndexesCenter(CoopGameSnapshot snapshot, List<int> indexes) {
    var dx = 0.0;
    var dy = 0.0;
    var count = 0;
    for (final index in indexes) {
      final row = index ~/ snapshot.cols;
      final col = index % snapshot.cols;
      if (row < 0 || row >= snapshot.rows || col < 0 || col >= snapshot.cols) {
        continue;
      }
      dx += col + 0.5;
      dy += row + 0.5;
      count++;
    }
    return count == 0 ? null : Offset(dx / count, dy / count);
  }

  bool _isDanger(CoopGameSnapshot snapshot) {
    for (var row = 0; row < 4 && row < snapshot.rows; row++) {
      final start = row * snapshot.cols;
      if (snapshot.cells
          .skip(start)
          .take(snapshot.cols)
          .any((cell) => cell != 0)) {
        return !snapshot.roundOver;
      }
    }
    return false;
  }

  void _showToast(String text, Color color, {bool big = false}) {
    _showToastData(
      ToastData(
        text,
        color,
        big: big,
        duration: big
            ? const Duration(milliseconds: 2400)
            : const Duration(milliseconds: 1850),
        backdrop: true,
      ),
    );
  }

  void _showToastData(ToastData data) {
    final id = _toastId++;
    if (!mounted) return;
    setState(() => _toasts[id] = data);
  }

  void _removeToast(int id) {
    if (mounted) setState(() => _toasts.remove(id));
  }

  Future<void> _haptic(Future<void> Function() feedback) async {
    if (!widget.settings.hapticsEnabled) return;
    try {
      await feedback();
    } catch (_) {}
  }

  void _playAcceptedAction(CoopAction action) {
    final sfx = switch (action) {
      CoopAction.left || CoopAction.right => Sfx.move,
      CoopAction.softDrop => Sfx.softDrop,
      CoopAction.rotateLeft || CoopAction.rotateRight => Sfx.rotate,
      CoopAction.mirror => Sfx.mirror,
      CoopAction.hardDrop => Sfx.hardDrop,
      CoopAction.fillCavity => Sfx.cavityFill,
    };
    // Mirror feedback is triggered from the authoritative snapshot so both
    // peers see and hear the same accepted flip without double-playing it.
    if (action != CoopAction.mirror) unawaited(widget.audio.play(sfx));
    if (action == CoopAction.hardDrop) {
      unawaited(_haptic(HapticFeedback.mediumImpact));
    } else if (action == CoopAction.fillCavity) {
      unawaited(_haptic(HapticFeedback.selectionClick));
    }
    if (action == CoopAction.fillCavity) {
      unawaited(widget.analytics.cavityFillUsed());
    } else if (action == CoopAction.mirror) {
      unawaited(widget.analytics.mirrorUsed());
    }
  }

  Sfx _clearSfx(int count) => switch (count) {
    1 => Sfx.clear1,
    2 => Sfx.clear2,
    3 => Sfx.clear3,
    _ => Sfx.clearFourLine,
  };

  Future<void> _recordHighScore(
    CoopGameSnapshot snapshot, {
    required bool isNewBest,
  }) async {
    if (snapshot.score <= 0) return;
    await widget.highScores.submitMultiplayerScore(
      snapshot.score,
      variant: widget.session.variant,
    );
    if (!isNewBest) return;
    await widget.leaderboard.submitMultiplayerScore(
      score: snapshot.score,
      level: 1 + snapshot.lines ~/ 10,
      isNewBest: true,
      variant: widget.session.variant,
    );
  }

  void _beginRound() {
    _roundNumber++;
    _roundStartedAt = DateTime.now();
    _roundWasNewBest = false;
    _effectCells = const [];
    _clearingRows = const [];
    _effectPlaybackTimer?.cancel();
    _effectPlaybackTimer = null;
    _pendingEffects.clear();
    _toasts.clear();
    _anim.resetForNewRun();
    for (final action in CoopAction.values) {
      _actionCounts[action] = 0;
    }
    unawaited(
      widget.analytics.multiplayerRoundStarted(
        role: _me.name,
        roundNumber: _roundNumber,
        variant: widget.session.variant.analyticsName,
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
        speedBonus: snapshot?.puzzleSpeedBonus ?? 0,
        variant: widget.session.variant.analyticsName,
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
    } else if (key == LogicalKeyboardKey.keyM &&
        widget.session.variant.allowsMirror) {
      _act(CoopAction.mirror);
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
    final puzzleSpeedBonusPreview =
        widget.session.variant.isPuzzle &&
            snapshot != null &&
            !snapshot.roundOver &&
            _roundStartedAt != null
        ? PuzzleSpeedBonus.forElapsed(
            DateTime.now().difference(_roundStartedAt!),
          )
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.session.variant.title} · ${widget.session.roomCode}',
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
              CoopScoreHud(
                connected: connected,
                score: snapshot?.score ?? 0,
                lines: snapshot?.lines ?? 0,
                combo: snapshot?.combo ?? 0,
                backToBack: snapshot?.backToBack ?? 0,
                redLines: snapshot?.redLines ?? 0,
                blueLines: snapshot?.blueLines ?? 0,
                bestScore: widget.highScores.bestMultiplayerScoreFor(
                  widget.session.variant,
                ),
                puzzleRowsRemaining: widget.session.variant.isPuzzle
                    ? snapshot?.puzzleRowsRemaining
                    : null,
                puzzleSpeedBonusPreview: puzzleSpeedBonusPreview,
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
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: duoBlColor.withValues(alpha: 0.2),
                                  blurRadius: 22,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: duoTrColor.withValues(alpha: 0.2),
                                  blurRadius: 22,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: RepaintBoundary(
                              child: AspectRatio(
                                aspectRatio: snapshot.cols / snapshot.rows,
                                child: AnimatedBuilder(
                                  animation: _anim.shake,
                                  builder: (context, child) =>
                                      Transform.translate(
                                        offset: _anim.shakeOffset,
                                        child: child,
                                      ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    clipBehavior: Clip.none,
                                    children: [
                                      CustomPaint(
                                        isComplex: true,
                                        willChange: true,
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
                                          anim: _anim,
                                          effectCells: _effectCells,
                                          clearingRows: _clearingRows,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (final entry
                                                    in _toasts.entries)
                                                  FloatingToast(
                                                    key: ValueKey(entry.key),
                                                    data: entry.value,
                                                    onDone: () =>
                                                        _removeToast(entry.key),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (snapshot.roundOver)
                                        _RoundOverOverlay(
                                          snapshot: snapshot,
                                          isNewBest: _roundWasNewBest,
                                          canRestart: _isHost,
                                          onRestart: _restart,
                                        ),
                                      if (!connected)
                                        const _DisconnectedOverlay(),
                                    ],
                                  ),
                                ),
                              ),
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
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  switch (widget.session.variant) {
                    CoopVariant.fixed =>
                      'Red owns ◢ · Blue owns ◥ · First to complete a line earns its fill',
                    CoopVariant.mirror =>
                      'Keep your color · Mirror your triangles · Clearer earns the fill',
                    CoopVariant.puzzle =>
                      'Co-op goal: reduce the formation to one occupied row · Mirror is enabled',
                  },
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              _CoopControls(
                enabled: connected && snapshot != null && !snapshot.roundOver,
                cavityCharges: snapshot?.cavityChargesFor(_me) ?? 0,
                accent: meColor,
                allowsMirror: widget.session.variant.allowsMirror,
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

class _CoopControls extends StatelessWidget {
  const _CoopControls({
    required this.enabled,
    required this.cavityCharges,
    required this.accent,
    required this.allowsMirror,
    required this.onAction,
  });

  final bool enabled;
  final int cavityCharges;
  final Color accent;
  final bool allowsMirror;
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
        if (allowsMirror) _button(Icons.flip, 'Mirror', CoopAction.mirror),
        _button(Icons.vertical_align_bottom, 'Drop', CoopAction.hardDrop),
        Tooltip(
          message: 'Fill the lowest cavity (G)',
          child: FilledButton.tonalIcon(
            onPressed: enabled && cavityCharges > 0
                ? () => onAction(CoopAction.fillCavity)
                : null,
            icon: const Icon(Icons.auto_fix_high, size: 20),
            label: Text('Fill x$cavityCharges'),
            style: FilledButton.styleFrom(foregroundColor: accent),
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
        style: FilledButton.styleFrom(foregroundColor: accent),
      );
}

class _RoundOverOverlay extends StatelessWidget {
  const _RoundOverOverlay({
    required this.snapshot,
    required this.isNewBest,
    required this.canRestart,
    required this.onRestart,
  });

  final CoopGameSnapshot snapshot;
  final bool isNewBest;
  final bool canRestart;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.76),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: 300,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  duoBlColor.withValues(alpha: 0.20),
                  const Color(0xFF151722).withValues(alpha: 0.96),
                  duoTrColor.withValues(alpha: 0.20),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.puzzleCleared ? 'PUZZLE CLEARED!' : 'TEAM GAME OVER',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isNewBest) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'NEW TEAM BEST!',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'TEAM SCORE',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  formatCoopScore(snapshot.score),
                  key: const ValueKey('coop-result-score'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: duoBlColor, blurRadius: 12),
                      Shadow(color: duoTrColor, blurRadius: 12),
                    ],
                  ),
                ),
                if (snapshot.puzzleCleared &&
                    snapshot.puzzleSpeedBonus > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'SPEED BONUS +${formatCoopScore(snapshot.puzzleSpeedBonus)}',
                    key: const ValueKey('coop-result-speed-bonus'),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '${snapshot.lines} LINES  ·  ${snapshot.fusions} FUSIONS\n'
                  'RED ${snapshot.redLines}  ·  BLUE ${snapshot.blueLines}\n'
                  'BEST COMBO x${snapshot.bestCombo}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 15),
                if (canRestart)
                  FilledButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.replay),
                    label: const Text('Play Again for Both'),
                  )
                else
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Waiting for the host to play again…',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
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
