import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/game_mode.dart';
import '../models/piece.dart';
import '../services/high_score_service.dart';
import '../ui/game_side_panel.dart';
import '../ui/mobile_stats_bar.dart';
import '../ui/widgets/floating_toast.dart';
import '../ui/widgets/touch_dpad.dart';
import 'board_painter.dart';
import 'game_animations.dart';
import 'game_board.dart';
import 'piece_bag.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode, required this.highScores});

  final GameMode mode;
  final HighScoreService highScores;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _config = Config();
  static const _previewCount = 3;
  static const _maxSpeedBoost = 8;

  late final GameAnimations _anim = GameAnimations(vsync: this);

  late GameBoard _board;
  ActivePiece? _active;
  PieceDefinition? _held;
  late List<PieceDefinition> _upcoming;
  GameState _state = GameState.paused;
  int _score = 0;
  int _lines = 0;
  Timer? _timer;
  Timer? _lockTimer;
  final _focusNode = FocusNode();
  final _rand = Random();
  late final PieceBag _pieceBag = PieceBag(random: _rand);
  int _cavityCharges = 1;
  int _speedBoost = 0;
  List<PieceCell> _lockedCells = const [];
  List<int> _clearingRows = const [];
  int _toastSeq = 0;
  final Map<int, ToastData> _toasts = {};
  int _combo = -1;
  int _lockResets = 0;
  bool _holdUsed = false;
  bool _resolvingLock = false;

  GameModeConfig get cfg => widget.mode.config;
  int get _level => 1 + (_lines ~/ 10);
  Duration get _tickSpeed => cfg.speedCurve(_level, _speedBoost);
  double get _scoreMultiplier => 1 + _speedBoost * 0.15;
  bool get _canAcceptInput =>
      _state == GameState.playing && !_resolvingLock && _active != null;
  bool get _canSpeedUp =>
      cfg.hasManualSpeedBoost &&
      _speedBoost < _maxSpeedBoost &&
      cfg.speedCurve(_level, _speedBoost + 1) < _tickSpeed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.highScores.addListener(_onHighScoresChanged);
    _resetBoard();
    _startGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.highScores.removeListener(_onHighScoresChanged);
    _timer?.cancel();
    _lockTimer?.cancel();
    _focusNode.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _onHighScoresChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _state == GameState.playing) {
      _setPaused(true);
    }
  }

  void _resetBoard() {
    _board = GameBoard(_config);
    _cavityCharges = 1;
  }

  void _startGame() {
    _timer?.cancel();
    _lockTimer?.cancel();
    _resetBoard();
    _score = 0;
    _lines = 0;
    _cavityCharges = 1;
    _speedBoost = 0;
    _state = GameState.playing;
    _resolvingLock = false;
    _toasts.clear();
    _combo = -1;
    _held = null;
    _holdUsed = false;
    _lockResets = 0;
    _pieceBag.reset();
    _upcoming = _pieceBag.takeMany(_previewCount);
    _spawnPiece();
    _restartTimer();
    setState(() {});
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_state != GameState.playing) return;
    _timer = Timer.periodic(_tickSpeed, (_) {
      if (_state == GameState.playing) {
        _tick();
      }
    });
  }

  int _scaledScore(int base) => (base * _scoreMultiplier).round();

  void _fillCavities() {
    if (!_canAcceptInput || !cfg.hasCavityFiller || _cavityCharges <= 0) {
      return;
    }
    if (_board.fillLowestCavity()) {
      _cavityCharges--;
      final cleared = _detectFullRows();
      if (cleared.isNotEmpty) {
        _collapseRows(cleared);
        final points = _scaledScore(_pointsForLines(cleared.length));
        _score += points;
        _lines += cleared.length;
        _cavityCharges += cleared.length;
        _combo++;
        _reconcileActiveAfterBoardMutation();
        _showToast('POWER CLEAR +$points', Colors.amberAccent);
        unawaited(HapticFeedback.mediumImpact());
      }
      _restartTimer();
      setState(() {});
    }
  }

  void _speedUp() {
    if (!_canAcceptInput || !_canSpeedUp) return;
    _speedBoost++;
    _restartTimer();
    _showToast(
      'RISK x${_scoreMultiplier.toStringAsFixed(2)}',
      Colors.orangeAccent,
    );
    unawaited(HapticFeedback.selectionClick());
    setState(() {});
  }

  int _pointsForLines(int cleared) {
    switch (cleared) {
      case 1:
        return 100 * _level;
      case 2:
        return 300 * _level;
      case 3:
        return 500 * _level;
      case 4:
        return 800 * _level;
      default:
        return 0;
    }
  }

  void _tick() {
    if (!_canAcceptInput) return;
    final next = _active!.copyWith(row: _active!.row + 1);
    final moved = _attemptMove(
      next,
      duration: _tickSpeed,
      curve: Curves.linear,
    );
    if (!moved) {
      _scheduleLock();
    }
  }

  void _scheduleLock() {
    if (!_canAcceptInput || _lockTimer != null) return;
    _lockTimer = Timer(const Duration(milliseconds: 450), () {
      _lockTimer = null;
      if (!_canAcceptInput) return;
      final below = _active!.copyWith(row: _active!.row + 1);
      if (_canPlace(below)) return;
      unawaited(_lockPiece());
    });
  }

  void _cancelLock() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  int _pieceWidth(PieceDefinition def) {
    final rotation = def.rotations.first;
    final maxCol = rotation.map((c) => c.col).reduce(max);
    final minCol = rotation.map((c) => c.col).reduce(min);
    return maxCol - minCol + 1;
  }

  void _spawnPiece({PieceDefinition? forcedType, bool resetHold = true}) {
    final type = forcedType ?? _upcoming.removeAt(0);
    if (forcedType == null) _upcoming.add(_pieceBag.take());
    _cancelLock();
    _lockResets = 0;
    if (resetHold) _holdUsed = false;
    final width = _pieceWidth(type);
    final spawnCol = ((_config.cols - width) ~/ 2).clamp(0, _config.cols - 1);
    _active = ActivePiece(type: type, row: 0, col: spawnCol);
    _anim.snapPiece(Offset(_active!.col.toDouble(), _active!.row.toDouble()));
    if (!_canPlace(_active!)) {
      _endGame();
    }
  }

  void _reconcileActiveAfterBoardMutation() {
    if (_active == null || _canPlace(_active!)) return;
    for (int offset = 1; offset < _config.rows; offset++) {
      final candidate = _active!.copyWith(row: _active!.row - offset);
      if (_canPlace(candidate)) {
        _active = candidate;
        _anim.snapPiece(
          Offset(candidate.col.toDouble(), candidate.row.toDouble()),
        );
        return;
      }
    }
    _endGame();
  }

  void _endGame() {
    if (_state == GameState.over) return;
    _state = GameState.over;
    _active = null;
    _timer?.cancel();
    _cancelLock();
    _resolvingLock = false;
    final isNewBest = _score > widget.highScores.bestScore(widget.mode);
    unawaited(
      widget.highScores.submitRun(widget.mode, score: _score, level: _level),
    );
    if (isNewBest) _showToast('NEW BEST!', Colors.amberAccent);
  }

  ActivePiece? get _ghostPiece {
    if (_active == null) return null;
    var ghost = _active!;
    while (true) {
      final next = ghost.copyWith(row: ghost.row + 1);
      if (!_canPlace(next)) return ghost;
      ghost = next;
    }
  }

  bool _canPlace(ActivePiece piece) => _board.canPlace(piece);

  bool _attemptMove(
    ActivePiece next, {
    required Duration duration,
    required Curve curve,
    bool manual = false,
  }) {
    if (!_canPlace(next)) return false;
    _active = next;
    _anim.retargetPiece(
      Offset(next.col.toDouble(), next.row.toDouble()),
      duration: duration,
      curve: curve,
    );
    if (manual && _lockTimer != null) {
      final below = next.copyWith(row: next.row + 1);
      if (_canPlace(below)) {
        _cancelLock();
      } else if (_lockResets < 15) {
        _lockResets++;
        _cancelLock();
        _scheduleLock();
      }
    }
    setState(() {});
    return true;
  }

  void _mirrorActive() {
    if (!_canAcceptInput) return;
    final toggled = _active!.copyWith(mirrored: !_active!.mirrored);
    final moved = _attemptMove(
      toggled,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      manual: true,
    );
    if (moved) unawaited(HapticFeedback.selectionClick());
  }

  bool _tryMove({int dx = 0, int dy = 0}) {
    if (!_canAcceptInput) return false;
    final next = _active!.copyWith(
      row: _active!.row + dy,
      col: _active!.col + dx,
    );
    return _attemptMove(
      next,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      manual: true,
    );
  }

  bool _tryRotate(int rotDelta) {
    if (!_canAcceptInput) return false;
    final rotCount = _active!.type.rotations.length;
    final rawRot = (_active!.rotation + rotDelta) % rotCount;
    final nextRot = rawRot < 0 ? rawRot + rotCount : rawRot;
    const kicks = [0, -1, 1, -2, 2];
    for (final dx in kicks) {
      final next = _active!.copyWith(col: _active!.col + dx, rotation: nextRot);
      if (_attemptMove(
        next,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        manual: true,
      )) {
        unawaited(HapticFeedback.selectionClick());
        return true;
      }
    }
    final floorKick = _active!.copyWith(
      row: _active!.row - 1,
      rotation: nextRot,
    );
    return _attemptMove(
      floorKick,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      manual: true,
    );
  }

  // Named so both the keyboard/desktop side panel and the mobile touch
  // D-pad can reference the exact same callbacks.
  void _moveLeft() => _tryMove(dx: -1);
  void _moveRight() => _tryMove(dx: 1);
  void _softDrop() {
    if (_tryMove(dy: 1)) {
      _score += _scaledScore(1);
      setState(() {});
    }
  }

  void _rotateLeft() => _tryRotate(-1);
  void _rotateRight() => _tryRotate(1);

  void _holdActive() {
    if (!_canAcceptInput || _holdUsed) return;
    final outgoing = _active!.type;
    final incoming = _held;
    _held = outgoing;
    _active = null;
    _holdUsed = true;
    _spawnPiece(forcedType: incoming, resetHold: false);
    unawaited(HapticFeedback.selectionClick());
    setState(() {});
  }

  void _hardDrop() {
    if (!_canAcceptInput) return;
    _cancelLock();
    int steps = 0;
    var candidate = _active!;
    while (true) {
      final next = candidate.copyWith(row: candidate.row + 1);
      if (!_canPlace(next)) break;
      candidate = next;
      steps++;
    }
    _active = candidate;
    _anim.retargetPiece(
      Offset(candidate.col.toDouble(), candidate.row.toDouble()),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeIn,
    );
    _anim.shake.forward(from: 0);
    if (steps >= 3) {
      final center = candidate.cellsOnBoard().first;
      _anim.burst(
        Offset(center.col + 0.5, center.row + 0.5),
        candidate.type.color,
        count: 10,
      );
    }
    _score += _scaledScore(steps * 2);
    unawaited(HapticFeedback.mediumImpact());
    setState(() {});
    unawaited(_lockPiece());
  }

  Future<void> _lockPiece() async {
    if (_active == null || _resolvingLock) return;
    _resolvingLock = true;
    _cancelLock();
    final lockedCells = _active!.cellsOnBoard();
    _board.lock(_active!);
    _active = null;
    _lockedCells = lockedCells;
    _anim.lockFlash.forward(from: 0);
    setState(() {});

    final clearedRows = _detectFullRows();
    if (clearedRows.isNotEmpty) {
      _clearingRows = clearedRows;
      setState(() {});
      await _anim.lineClear.forward(from: 0);
      if (!mounted) return;

      for (final r in clearedRows) {
        for (int c = 0; c < _config.cols; c++) {
          final cell = _board.cells[r][c];
          final color = cell.full ?? cell.bl ?? cell.tr!;
          _anim.burst(Offset(c + 0.5, r + 0.5), color, count: 6);
        }
      }
      if (clearedRows.length >= 3) _anim.shake.forward(from: 0);
      unawaited(HapticFeedback.heavyImpact());

      _collapseRows(clearedRows);
      final levelBefore = _level;
      final points = _scaledScore(_pointsForLines(clearedRows.length));
      _score += points;
      _lines += clearedRows.length;
      if (cfg.hasCavityFiller) _cavityCharges += clearedRows.length;
      _clearingRows = const [];
      _combo++;

      final accent = Theme.of(context).colorScheme.primary;
      if (clearedRows.length == 4) {
        _showToast('TETRIS!', Colors.amberAccent, big: true);
      } else {
        _showToast('+$points', Colors.white);
      }
      if (_level > levelBefore) {
        _showToast('LEVEL $_level!', accent);
      }
      if (_combo > 0) {
        final heat = (_combo / 6).clamp(0.0, 1.0);
        _showToast(
          '${_combo + 1}x COMBO!',
          Color.lerp(accent, Colors.redAccent, heat)!,
          big: _combo >= 2,
        );
      }
    } else {
      _combo = -1;
    }
    _lockedCells = const [];
    _resolvingLock = false;
    _spawnPiece();
    _restartTimer();
    setState(() {});
  }

  List<int> _detectFullRows() => _board.detectFullRows();

  void _collapseRows(List<int> rows) => _board.collapseRows(rows);

  void _showToast(String text, Color color, {bool big = false}) {
    final id = _toastSeq++;
    setState(() => _toasts[id] = ToastData(text, color, big: big));
  }

  void _removeToast(int id) {
    setState(() => _toasts.remove(id));
  }

  void _setPaused(bool paused) {
    if (paused && _state == GameState.playing) {
      _timer?.cancel();
      _cancelLock();
      setState(() => _state = GameState.paused);
    } else if (!paused && _state == GameState.paused) {
      setState(() => _state = GameState.playing);
      _restartTimer();
      if (_active != null &&
          !_canPlace(_active!.copyWith(row: _active!.row + 1))) {
        _scheduleLock();
      }
    }
  }

  void _togglePause() {
    if (_state == GameState.over) return;
    _setPaused(_state == GameState.playing);
  }

  void _pauseOrPlay() {
    if (_state == GameState.over) {
      _startGame();
    } else {
      _togglePause();
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final isRepeat = event is KeyRepeatEvent;
    final key = event.logicalKey;
    if (_state == GameState.over && key == LogicalKeyboardKey.space) {
      _startGame();
      return;
    }
    if (isRepeat &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight &&
        key != LogicalKeyboardKey.arrowDown) {
      return;
    }
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        _moveLeft();
        break;
      case LogicalKeyboardKey.arrowRight:
        _moveRight();
        break;
      case LogicalKeyboardKey.arrowDown:
        _softDrop();
        break;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
        _rotateRight();
        break;
      case LogicalKeyboardKey.keyQ:
      case LogicalKeyboardKey.keyZ:
        _rotateLeft();
        break;
      case LogicalKeyboardKey.keyM:
        _mirrorActive();
        break;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.shiftLeft:
      case LogicalKeyboardKey.shiftRight:
        _holdActive();
        break;
      case LogicalKeyboardKey.space:
        _hardDrop();
        break;
      case LogicalKeyboardKey.keyG:
        _fillCavities();
        break;
      case LogicalKeyboardKey.keyP:
      case LogicalKeyboardKey.escape:
        _togglePause();
        break;
    }
  }

  static const double _mobileBreakpoint = 600;

  Widget _buildBoard(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Center(
      child: AspectRatio(
        aspectRatio: _config.cols / _config.rows,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _anim.shake,
                  builder: (context, child) => Transform.translate(
                    offset: _anim.shakeOffset,
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.55),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: accent.withValues(alpha: 0.30),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: accent.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: BoardPainter(
                        board: _board.cells,
                        active: _active,
                        ghost: _state == GameState.playing ? _ghostPiece : null,
                        config: _config,
                        boardRevision: _board.revision,
                        state: _state,
                        lockedCells: _lockedCells,
                        clearingRows: _clearingRows,
                        anim: _anim,
                      ),
                    ),
                  ),
                ),
              ),
              for (final entry in _toasts.entries)
                if (entry.value.big)
                  FloatingToast(
                    key: ValueKey(entry.key),
                    data: entry.value,
                    onDone: () => _removeToast(entry.key),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    final panelWidth = min(260.0, constraints.maxWidth * 0.28);
    return Row(
      children: [
        Expanded(child: _buildBoard(context)),
        GameSidePanel(
          width: panelWidth,
          mode: widget.mode,
          state: _state,
          score: _score,
          lines: _lines,
          level: _level,
          bestScore: widget.highScores.bestScore(widget.mode),
          bestLevel: widget.highScores.bestLevel(widget.mode),
          cavityCharges: _cavityCharges,
          speedBoost: _speedBoost,
          upcoming: _upcoming,
          held: _held,
          canHold: !_holdUsed,
          canSpeedUp: _canSpeedUp,
          toasts: _toasts,
          onRemoveToast: _removeToast,
          onPauseOrPlay: _pauseOrPlay,
          onRestart: _startGame,
          onMoveLeft: _moveLeft,
          onMoveRight: _moveRight,
          onSoftDrop: _softDrop,
          onHardDrop: _hardDrop,
          onRotateLeft: _rotateLeft,
          onRotateRight: _rotateRight,
          onMirror: _mirrorActive,
          onHold: _holdActive,
          onSpeedUp: _speedUp,
          onFillCavities: _fillCavities,
          onMenu: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: _buildBoard(context)),
          MobileStatsBar(
            state: _state,
            score: _score,
            lines: _lines,
            level: _level,
            upcoming: _upcoming,
            onPauseOrPlay: _pauseOrPlay,
            onMenu: () => Navigator.of(context).pop(),
          ),
          TouchDpad(
            enabled: _state == GameState.playing && !_resolvingLock,
            onMoveLeft: _moveLeft,
            onMoveRight: _moveRight,
            onSoftDrop: _softDrop,
            onRotateLeft: _rotateLeft,
            onRotateRight: _rotateRight,
            onMirror: _mirrorActive,
            onHold: _holdActive,
            canHold: !_holdUsed,
            onHardDrop: _hardDrop,
            onFillCavities: cfg.hasCavityFiller ? _fillCavities : null,
            cavityCharges: _cavityCharges,
            onSpeedUp: cfg.hasManualSpeedBoost ? _speedUp : null,
            speedBoost: _speedBoost,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return constraints.maxWidth < _mobileBreakpoint
                ? _buildMobileLayout(context)
                : _buildDesktopLayout(context, constraints);
          },
        ),
      ),
    );
  }
}
