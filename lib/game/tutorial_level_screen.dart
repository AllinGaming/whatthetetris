import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/pieces.dart';
import '../models/theme_palette.dart';
import '../services/settings_service.dart';
import '../ui/widgets/neon_text.dart';
import '../ui/widgets/touch_dpad.dart';
import 'board_painter.dart';
import 'game_animations.dart';
import 'game_board.dart';

enum _Step { moveRotateDrop, mirror, fusion, hold, cavityFill, done }

/// A real, playable mini board that teaches this game's mechanics by doing
/// them. Deliberately consequence-free: no score, no stats, and — unlike
/// real gameplay — no gravity timer at all. A piece just sits until moved
/// or dropped, which keeps every step fully player-paced and removes any
/// timer-vs-step race to worry about.
///
/// Mirrors [GameScreen]'s own dual input model rather than being
/// keyboard-only: a [TouchDpad] on mobile under [TouchControlScheme.buttons]
/// (the default), or the same swipe/tap/double-tap/long-press board
/// gestures under [TouchControlScheme.gestures] — otherwise this screen is
/// simply unplayable on a phone with no physical keyboard.
class TutorialLevelScreen extends StatefulWidget {
  const TutorialLevelScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<TutorialLevelScreen> createState() => _TutorialLevelScreenState();
}

class _TutorialLevelScreenState extends State<TutorialLevelScreen>
    with TickerProviderStateMixin {
  static const _config = Config(rows: 10, cols: 6);
  static const _theme = ThemePalette.neon;
  static const _mobileBreakpoint = 600.0;

  /// Same simplified kick table as the real game (docs/GDD.md SS4.4) — kept
  /// identical so rotation feels the same here as it will in a real run.
  static const _kicks = [0, -1, 1, -2, 2];

  /// Same thresholds [GameScreen] uses for its board gestures, so drag/
  /// swipe/fling feel identical here and in a real run.
  static const _dragLockThreshold = 8.0;
  static const _hardDropFlingVelocity = 1200.0;
  static const _rotateSwipeVelocity = 700.0;

  late GameBoard _board;
  late final GameAnimations _anim = GameAnimations(vsync: this);
  final _boardStaticCache = BoardStaticCache();
  final _focusNode = FocusNode();

  double _cellSize = 1;
  double _dragDx = 0;
  double _dragDy = 0;
  bool? _dragHorizontal;

  _Step _step = _Step.moveRotateDrop;
  ActivePiece? _active;
  bool _movedOnce = false;
  bool _rotatedOnce = false;
  bool _readyToDrop = false;
  int _cavityCharges = 0;
  String? _successMessage;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _setupStep(_Step.moveRotateDrop);
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _anim.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  PieceDefinition _pieceNamed(String name) =>
      Pieces.all.firstWhere((p) => p.name == name);

  int _pieceWidth(PieceDefinition type) {
    final rotation = type.rotations.first;
    final maxCol = rotation.map((c) => c.col).reduce(max);
    final minCol = rotation.map((c) => c.col).reduce(min);
    return maxCol - minCol + 1;
  }

  void _spawn(PieceDefinition type) {
    final width = _pieceWidth(type);
    final col = ((_config.cols - width) ~/ 2).clamp(0, _config.cols - 1);
    _active = ActivePiece(type: type, row: 0, col: col);
    _anim.snapPiece(Offset(_active!.col.toDouble(), _active!.row.toDouble()));
  }

  /// Resets the board and stages whatever the next step needs, then spawns
  /// its forced piece (if any) — every step starts clean so nothing a prior
  /// step locked can clutter or block the next lesson.
  void _setupStep(_Step step) {
    _board = GameBoard(_config);
    _active = null;
    _movedOnce = false;
    _rotatedOnce = false;
    _readyToDrop = false;
    _cavityCharges = 0;
    switch (step) {
      case _Step.moveRotateDrop:
        _spawn(_pieceNamed('T4'));
      case _Step.mirror:
        _spawn(_pieceNamed('S4'));
      case _Step.fusion:
        // A full row of unfused halves rather than one exact target cell —
        // any mirrored piece dropped anywhere on it guarantees a fusion, so
        // the lesson doesn't hinge on pixel-precise column alignment.
        for (int c = 0; c < _config.cols; c++) {
          _board.cells[_config.rows - 1][c].bl = duoBlColor;
        }
        _board.revision++;
        _spawn(_pieceNamed('L4'));
      case _Step.hold:
        _spawn(_pieceNamed('O4'));
      case _Step.cavityFill:
        _board.cells[_config.rows - 1][3].tr = duoTrColor;
        _board.revision++;
        _cavityCharges = 1;
      case _Step.done:
        break;
    }
    setState(() => _step = step);
  }

  bool get _canAct => _active != null && _step != _Step.done;

  void _move(int dx, int dy) {
    if (!_canAct) return;
    final next = _active!.copyWith(
      row: _active!.row + dy,
      col: _active!.col + dx,
    );
    if (!_board.canPlace(next)) return;
    _active = next;
    _anim.retargetPiece(
      Offset(next.col.toDouble(), next.row.toDouble()),
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
    if (dx != 0) _movedOnce = true;
    if (_movedOnce && _rotatedOnce) _readyToDrop = true;
    setState(() {});
  }

  void _rotate(int delta) {
    if (!_canAct) return;
    final piece = _active!;
    final rotCount = piece.type.rotations.length;
    final rawRot = (piece.rotation + delta) % rotCount;
    final nextRot = rawRot < 0 ? rawRot + rotCount : rawRot;
    for (final dx in _kicks) {
      final next = piece.copyWith(col: piece.col + dx, rotation: nextRot);
      if (_board.canPlace(next)) {
        _active = next;
        _anim.retargetPiece(
          Offset(next.col.toDouble(), next.row.toDouble()),
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
        );
        _rotatedOnce = true;
        if (_movedOnce && _rotatedOnce) _readyToDrop = true;
        setState(() {});
        return;
      }
    }
  }

  void _mirror() {
    if (!_canAct) return;
    final toggled = _active!.copyWith(mirrored: !_active!.mirrored);
    if (!_board.canPlace(toggled)) return;
    _active = toggled;
    setState(() {});
  }

  void _hold() {
    // Only wired during its own step -- a full swap-back model isn't needed
    // just to teach "press C to set a piece aside."
    if (_step != _Step.hold || _active == null) return;
    _active = null;
    setState(() {});
    _completeStep();
  }

  Color _cavityFillColor(TriHalf fillTri, Color existing) =>
      fillTri == TriHalf.tr ? duoTrColor : duoBlColor;

  /// The keyboard-G / D-pad-button path.
  void _cavityFillLowest() {
    if (_step != _Step.cavityFill || _cavityCharges <= 0) return;
    if (_board.fillLowestCavity(colorForFill: _cavityFillColor) != null) {
      _onCavityFilled();
    }
  }

  /// The gesture scheme's tap-a-specific-cell path (see [_handleBoardTap]),
  /// matching how the real game's gesture scheme works.
  void _cavityFillAt(int row, int col) {
    if (_step != _Step.cavityFill || _cavityCharges <= 0) return;
    if (_board.fillCavityAt(row, col, colorForFill: _cavityFillColor)) {
      _onCavityFilled();
    }
  }

  void _onCavityFilled() {
    _cavityCharges--;
    setState(() {});
    _completeStep();
  }

  void _hardDrop() {
    if (!_canAct) return;
    var candidate = _active!;
    while (true) {
      final next = candidate.copyWith(row: candidate.row + 1);
      if (!_board.canPlace(next)) break;
      candidate = next;
    }
    final fusions = _board.countFusions(candidate);
    final mirroredAtLock = candidate.mirrored;
    _board.lock(
      candidate,
      colorForCell: (cell) => resolveCellColor(
        mode: PieceColorMode.duo,
        themedColor: _theme.accent,
        kind: cell.kind,
        tri: cell.tri,
      ),
    );
    _anim.lockFlash.forward(from: 0);
    _active = null;
    setState(() {});
    _onLocked(fusions: fusions, mirroredAtLock: mirroredAtLock);
  }

  void _onLocked({required int fusions, required bool mirroredAtLock}) {
    switch (_step) {
      case _Step.moveRotateDrop:
        _completeStep();
      case _Step.mirror:
        if (mirroredAtLock) {
          _completeStep();
        } else {
          _setupStep(_Step.mirror);
        }
      case _Step.fusion:
        if (fusions >= 1) {
          _completeStep();
        } else {
          _setupStep(_Step.fusion);
        }
      case _Step.hold:
      case _Step.cavityFill:
      case _Step.done:
        break;
    }
  }

  void _completeStep() {
    setState(() => _successMessage = 'Nice!');
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _successMessage = null;
      final next = _Step.values[_step.index + 1];
      _setupStep(next);
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final isRepeat = event is KeyRepeatEvent;
    final key = event.logicalKey;
    if (isRepeat &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight &&
        key != LogicalKeyboardKey.arrowDown) {
      return;
    }
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        _move(-1, 0);
        break;
      case LogicalKeyboardKey.arrowRight:
        _move(1, 0);
        break;
      case LogicalKeyboardKey.arrowDown:
        _move(0, 1);
        break;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
        _rotate(1);
        break;
      case LogicalKeyboardKey.keyQ:
      case LogicalKeyboardKey.keyZ:
        _rotate(-1);
        break;
      case LogicalKeyboardKey.keyM:
        _mirror();
        break;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.shiftLeft:
      case LogicalKeyboardKey.shiftRight:
        _hold();
        break;
      case LogicalKeyboardKey.space:
        _hardDrop();
        break;
      case LogicalKeyboardKey.keyG:
        _cavityFillLowest();
        break;
    }
  }

  bool get _gestureScheme =>
      widget.settings.touchControlScheme == TouchControlScheme.gestures;

  /// The board cell under a local tap position, or null if it fell outside
  /// the board -- see `GameScreen._cellAt`, the same reasoning applies here
  /// (a single cell size covers both axes since the board's aspect ratio is
  /// locked to [_config]'s rows/cols).
  (int, int)? _cellAt(Offset localPosition) {
    if (_cellSize <= 0) return null;
    final row = (localPosition.dy / _cellSize).floor();
    final col = (localPosition.dx / _cellSize).floor();
    if (row < 0 || row >= _config.rows || col < 0 || col >= _config.cols) {
      return null;
    }
    return (row, col);
  }

  bool _isCavityCell(int row, int col) {
    final cell = _board.cells[row][col];
    if (cell.full != null) return false;
    return (cell.bl != null) != (cell.tr != null);
  }

  /// Same board-tap semantics as the real game: rotates under
  /// [TouchControlScheme.buttons], but under [TouchControlScheme.gestures]
  /// a tap mirrors instead -- unless it lands on a cavity cell, in which
  /// case it fills that specific cavity.
  void _handleBoardTap(Offset localPosition) {
    if (!_gestureScheme) {
      _rotate(1);
      return;
    }
    final cell = _cellAt(localPosition);
    if (cell != null && _isCavityCell(cell.$1, cell.$2)) {
      _cavityFillAt(cell.$1, cell.$2);
      return;
    }
    _mirror();
  }

  void _onBoardPanStart(DragStartDetails details) {
    _dragDx = 0;
    _dragDy = 0;
    _dragHorizontal = null;
  }

  void _onBoardPanUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
    _dragDy += details.delta.dy;
    _dragHorizontal ??=
        (_dragDx.abs() >= _dragLockThreshold ||
            _dragDy.abs() >= _dragLockThreshold)
        ? _dragDx.abs() >= _dragDy.abs()
        : null;

    if (_cellSize <= 0) return;
    if (_dragHorizontal == true) {
      while (_dragDx >= _cellSize) {
        _move(1, 0);
        _dragDx -= _cellSize;
      }
      while (_dragDx <= -_cellSize) {
        _move(-1, 0);
        _dragDx += _cellSize;
      }
    } else if (_dragHorizontal == false) {
      while (_dragDy >= _cellSize) {
        _move(0, 1);
        _dragDy -= _cellSize;
      }
      if (_dragDy < 0) _dragDy = 0; // dragging back up never moves it down
    }
  }

  void _onBoardPanEnd(DragEndDetails details) {
    if (_dragHorizontal == false) {
      final dy = details.velocity.pixelsPerSecond.dy;
      if (dy > _hardDropFlingVelocity) {
        _hardDrop();
      } else if (_gestureScheme && dy < -_rotateSwipeVelocity) {
        _rotate(1);
      }
    }
    _dragDx = 0;
    _dragDy = 0;
    _dragHorizontal = null;
  }

  String get _instruction {
    if (_successMessage != null) return _successMessage!;
    return switch (_step) {
      _Step.moveRotateDrop =>
        _readyToDrop ? 'Now drop it!' : 'Move it, then rotate it.',
      _Step.mirror => "This piece won't fuse as-is — mirror it, then drop it.",
      _Step.fusion =>
        'Mirror it, then drop it anywhere on the bottom row to fuse it.',
      _Step.hold => 'Hold this piece for later.',
      _Step.cavityFill => 'Fill that stray gap.',
      _Step.done => "You're ready — go play!",
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.done) return _buildDone(context);

    final accent = _theme.accent;
    return Scaffold(
      backgroundColor: _theme.backgroundBottom,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < _mobileBreakpoint;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _instruction,
                            style: TextStyle(
                              color: _successMessage != null
                                  ? Colors.greenAccent
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              shadows: neonShadows(accent, intensity: 0.5),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  ),
                  _buildStepDots(accent),
                  const SizedBox(height: 8),
                  Expanded(child: _buildBoardArea(accent)),
                  // Buttons scheme gets the same on-screen D-pad the real
                  // game uses; gestures scheme plays entirely on the board
                  // itself (see the GestureDetector in _buildBoardArea), so
                  // showing the pad too would just be redundant.
                  if (mobile && !_gestureScheme) ...[
                    const SizedBox(height: 12),
                    _buildTouchDpad(),
                  ],
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBoardArea(Color accent) {
    return Center(
      child: AspectRatio(
        aspectRatio: _config.cols / _config.rows,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _cellSize = constraints.maxWidth / _config.cols;
            return GestureDetector(
              onTapUp: (details) => _handleBoardTap(details.localPosition),
              // Only wired under gestures -- adding it unconditionally
              // would make Flutter wait out the double-tap timeout before
              // ever firing a plain tap, adding input lag under buttons.
              onDoubleTap: _gestureScheme ? _hardDrop : null,
              onLongPress: _hold,
              onPanStart: _onBoardPanStart,
              onPanUpdate: _onBoardPanUpdate,
              onPanEnd: _onBoardPanEnd,
              child: CustomPaint(
                painter: BoardPainter(
                  board: _board.cells,
                  active: _active,
                  ghost: null,
                  config: _board.config,
                  boardRevision: _board.revision,
                  state: GameState.playing,
                  lockedCells: const [],
                  clearingRows: const [],
                  anim: _anim,
                  theme: _theme,
                  colorMode: PieceColorMode.duo,
                  activeThemeColor: accent,
                  staticCache: _boardStaticCache,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTouchDpad() {
    return TouchDpad(
      enabled: _canAct,
      onMoveLeft: () => _move(-1, 0),
      onMoveRight: () => _move(1, 0),
      onSoftDrop: () => _move(0, 1),
      onRotateLeft: () => _rotate(-1),
      onRotateRight: () => _rotate(1),
      onMirror: _mirror,
      onHold: _hold,
      canHold: true,
      onHardDrop: _hardDrop,
      onFillCavities: _cavityFillLowest,
      cavityCharges: _cavityCharges,
      onSpeedUp: null,
      speedBoost: 0,
      reduceMotion: widget.settings.reduceMotion,
      handedness: widget.settings.touchHandedness,
    );
  }

  Widget _buildStepDots(Color accent) {
    final stepCount = _Step.values.length - 1; // exclude the "done" marker
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < stepCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _step.index ? accent : Colors.white24,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final accent = _theme.accent;
    return Scaffold(
      backgroundColor: _theme.backgroundBottom,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 64, color: accent),
                const SizedBox(height: 16),
                Text(
                  "You're ready — go play!",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    shadows: neonShadows(accent),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Finish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
