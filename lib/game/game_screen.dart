import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/game_mode.dart';
import '../models/piece.dart';
import '../models/pieces.dart';
import '../services/high_score_service.dart';
import '../ui/game_side_panel.dart';
import '../ui/mobile_stats_bar.dart';
import '../ui/widgets/floating_toast.dart';
import '../ui/widgets/touch_dpad.dart';
import 'board_painter.dart';
import 'game_animations.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode, required this.highScores});

  final GameMode mode;
  final HighScoreService highScores;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const _config = Config();

  late final GameAnimations _anim = GameAnimations(vsync: this);

  late List<List<CellOccupancy>> _board;
  ActivePiece? _active;
  late PieceDefinition _upcoming;
  GameState _state = GameState.paused;
  int _score = 0;
  int _lines = 0;
  Timer? _timer;
  final _focusNode = FocusNode();
  final _rand = Random();
  int _cavityCharges = 1;
  int _speedBoost = 0;
  List<PieceCell> _lockedCells = const [];
  List<int> _clearingRows = const [];
  int _toastSeq = 0;
  final Map<int, ToastData> _toasts = {};
  int _combo = -1;

  GameModeConfig get cfg => widget.mode.config;
  int get _level => 1 + (_lines ~/ 10);
  Duration get _tickSpeed => cfg.speedCurve(_level, _speedBoost);

  @override
  void initState() {
    super.initState();
    _resetBoard();
    _startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _resetBoard() {
    _board = List.generate(
      _config.rows,
      (_) => List.generate(_config.cols, (_) => CellOccupancy()),
    );
    _cavityCharges = 1;
  }

  void _startGame() {
    _resetBoard();
    _score = 0;
    _lines = 0;
    _cavityCharges = 1;
    _speedBoost = 0;
    _state = GameState.playing;
    _toasts.clear();
    _combo = -1;
    _upcoming = _randomPieceType();
    _spawnPiece();
    _restartTimer();
    setState(() {});
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickSpeed, (_) {
      if (_state == GameState.playing) {
        _tick();
      }
    });
  }

  void _fillCavities() {
    if (!cfg.hasCavityFiller || _cavityCharges <= 0) return;
    int filled = 0;
    for (int r = _config.rows - 1; r >= 0 && filled < 1; r--) {
      for (int c = 0; c < _config.cols && filled < 1; c++) {
        final cell = _board[r][c];
        if (cell.full != null) continue;
        final hasBl = cell.bl != null;
        final hasTr = cell.tr != null;
        if (hasBl == hasTr) continue; // skip empty or already full
        final color = hasBl ? cell.bl! : cell.tr!;
        if (!hasBl) {
          cell.bl = color;
        } else {
          cell.tr = color;
        }
        filled++;
      }
    }
    if (filled > 0) {
      _cavityCharges--;
      final cleared = _detectFullRows();
      if (cleared.isNotEmpty) {
        _collapseRows(cleared);
        _score += _pointsForLines(cleared.length);
        _lines += cleared.length;
        _cavityCharges += cleared.length;
      }
      _restartTimer();
      setState(() {});
    }
  }

  void _speedUp() {
    if (!cfg.hasManualSpeedBoost) return;
    _speedBoost++;
    _score += 25 * _speedBoost;
    _restartTimer();
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
    if (_active == null) return;
    final next = _active!.copyWith(row: _active!.row + 1);
    final moved = _attemptMove(
      next,
      duration: _tickSpeed,
      curve: Curves.linear,
    );
    if (!moved) {
      _lockPiece();
    }
  }

  PieceDefinition _randomPieceType() => Pieces.all[_rand.nextInt(Pieces.all.length)];

  int _pieceWidth(PieceDefinition def) {
    final rotation = def.rotations.first;
    final maxCol = rotation.map((c) => c.col).reduce(max);
    final minCol = rotation.map((c) => c.col).reduce(min);
    return maxCol - minCol + 1;
  }

  void _spawnPiece() {
    final type = _upcoming;
    _upcoming = _randomPieceType();
    final width = _pieceWidth(type);
    final spawnCol = ((_config.cols - width) ~/ 2).clamp(0, _config.cols - 1);
    _active = ActivePiece(type: type, row: 0, col: spawnCol);
    _anim.snapPiece(Offset(_active!.col.toDouble(), _active!.row.toDouble()));
    if (!_canPlace(_active!)) {
      _state = GameState.over;
      _active = null;
      final isNewBest = _score > widget.highScores.bestScore(widget.mode);
      unawaited(
        widget.highScores.submitRun(widget.mode, score: _score, level: _level),
      );
      if (isNewBest) _showToast('NEW BEST!', Colors.amberAccent);
    }
  }

  bool _canPlace(ActivePiece piece) {
    for (final cell in piece.cellsOnBoard()) {
      if (cell.row < 0 || cell.row >= _config.rows) {
        return false;
      }
      if (cell.col < 0 || cell.col >= _config.cols) {
        return false;
      }
      final target = _board[cell.row][cell.col];
      if (target.full != null) return false;
      // Stop only on same-orientation triangles; opposite halves can be entered
      // so they merge when the piece eventually locks.
      if (cell.tri == TriHalf.bl && target.bl != null) return false;
      if (cell.tri == TriHalf.tr && target.tr != null) return false;
    }
    return true;
  }

  bool _attemptMove(
    ActivePiece next, {
    required Duration duration,
    required Curve curve,
  }) {
    if (!_canPlace(next)) return false;
    _active = next;
    _anim.retargetPiece(
      Offset(next.col.toDouble(), next.row.toDouble()),
      duration: duration,
      curve: curve,
    );
    setState(() {});
    return true;
  }

  void _mirrorActive() {
    if (_active == null) return;
    final toggled = _active!.copyWith(mirrored: !_active!.mirrored);
    _attemptMove(
      toggled,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
  }

  bool _tryMove({int dx = 0, int dy = 0, int rotDelta = 0}) {
    if (_active == null) return false;
    final rotCount = _active!.type.rotations.length;
    final rawRot = (_active!.rotation + rotDelta) % rotCount;
    final nextRot = rawRot < 0 ? rawRot + rotCount : rawRot;
    final next = _active!.copyWith(
      row: _active!.row + dy,
      col: _active!.col + dx,
      rotation: nextRot,
    );
    return _attemptMove(
      next,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
  }

  // Named so both the keyboard/desktop side panel and the mobile touch
  // D-pad can reference the exact same callbacks.
  void _moveLeft() => _tryMove(dx: -1);
  void _moveRight() => _tryMove(dx: 1);
  void _softDrop() => _tryMove(dy: 1);
  void _rotateLeft() => _tryMove(rotDelta: -1);
  void _rotateRight() => _tryMove(rotDelta: 1);

  void _hardDrop() {
    if (_active == null) return;
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
    _score += steps * 2;
    setState(() {});
    _lockPiece();
  }

  Future<void> _lockPiece() async {
    if (_active == null) return;
    final lockedCells = _active!.cellsOnBoard();
    for (final cell in lockedCells) {
      final target = _board[cell.row][cell.col];
      if (cell.kind == CellKind.full) {
        target.full = _active!.type.color;
      } else {
        if (cell.tri == TriHalf.bl) {
          target.bl = _active!.type.color;
        } else {
          target.tr = _active!.type.color;
        }
      }
    }
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
          final cell = _board[r][c];
          final color = cell.full ?? cell.bl ?? cell.tr!;
          _anim.burst(Offset(c + 0.5, r + 0.5), color, count: 6);
        }
      }
      if (clearedRows.length >= 3) _anim.shake.forward(from: 0);

      _collapseRows(clearedRows);
      final levelBefore = _level;
      final points = _pointsForLines(clearedRows.length);
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
    _spawnPiece();
    _restartTimer();
    setState(() {});
  }

  List<int> _detectFullRows() => [
    for (int r = 0; r < _config.rows; r++)
      if (_board[r].every((c) => c.isFullyFilled)) r,
  ];

  void _collapseRows(List<int> rows) {
    if (rows.isEmpty) return;
    final rowSet = rows.toSet();
    final remaining = [
      for (int r = 0; r < _config.rows; r++)
        if (!rowSet.contains(r)) _board[r],
    ];
    _board = [
      ...List.generate(
        rows.length,
        (_) => List.generate(_config.cols, (_) => CellOccupancy()),
      ),
      ...remaining,
    ];
  }

  void _showToast(String text, Color color, {bool big = false}) {
    final id = _toastSeq++;
    setState(() => _toasts[id] = ToastData(text, color, big: big));
  }

  void _removeToast(int id) {
    setState(() => _toasts.remove(id));
  }

  void _togglePause() {
    setState(() {
      _state = _state == GameState.playing
          ? GameState.paused
          : GameState.playing;
    });
  }

  void _pauseOrPlay() {
    if (_state == GameState.over) {
      _startGame();
    } else {
      _togglePause();
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_state == GameState.over && event.logicalKey.keyLabel == ' ') {
      _startGame();
      return;
    }
    switch (event.logicalKey.keyLabel) {
      case 'Arrow Left':
        _moveLeft();
        break;
      case 'Arrow Right':
        _moveRight();
        break;
      case 'Arrow Down':
        _softDrop();
        break;
      case 'Arrow Up':
      case 'w':
      case 'W':
        _rotateRight();
        break;
      case 'q':
      case 'Q':
      case 'z':
      case 'Z':
        _rotateLeft();
        break;
      case 'm':
      case 'M':
        _mirrorActive();
        break;
      case ' ':
        _hardDrop();
        break;
      case 'g':
      case 'G':
        _fillCavities();
        break;
      case 'p':
      case 'P':
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
                        board: _board,
                        active: _active,
                        config: _config,
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
            onMoveLeft: _moveLeft,
            onMoveRight: _moveRight,
            onSoftDrop: _softDrop,
            onRotateLeft: _rotateLeft,
            onRotateRight: _rotateRight,
            onMirror: _mirrorActive,
            onHardDrop: _hardDrop,
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
