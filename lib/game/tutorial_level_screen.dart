import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/pieces.dart';
import '../models/theme_palette.dart';
import '../ui/widgets/neon_text.dart';
import 'board_painter.dart';
import 'game_animations.dart';
import 'game_board.dart';

enum _Step { moveRotateDrop, mirror, fusion, hold, cavityFill, done }

/// A real, playable mini board that teaches this game's mechanics by doing
/// them, rather than the isolated demo widgets in [TutorialOverlay] (shown
/// right before this, whose final "Let's go" leads here). Deliberately
/// consequence-free: no score, no stats, and — unlike real gameplay — no
/// gravity timer at all. A piece just sits until moved or dropped, which
/// keeps every step fully player-paced and removes any timer-vs-step race
/// to worry about.
class TutorialLevelScreen extends StatefulWidget {
  const TutorialLevelScreen({super.key});

  @override
  State<TutorialLevelScreen> createState() => _TutorialLevelScreenState();
}

class _TutorialLevelScreenState extends State<TutorialLevelScreen>
    with TickerProviderStateMixin {
  static const _config = Config(rows: 10, cols: 6);
  static const _theme = ThemePalette.neon;

  /// Same simplified kick table as the real game (docs/GDD.md SS4.4) — kept
  /// identical so rotation feels the same here as it will in a real run.
  static const _kicks = [0, -1, 1, -2, 2];

  late GameBoard _board;
  late final GameAnimations _anim = GameAnimations(vsync: this);
  final _focusNode = FocusNode();

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

  void _cavityFill() {
    if (_step != _Step.cavityFill || _cavityCharges <= 0) return;
    final filled = _board.fillLowestCavity(
      colorForFill: (fillTri, existing) =>
          fillTri == TriHalf.tr ? duoTrColor : duoBlColor,
    );
    if (!filled) return;
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
        _cavityFill();
        break;
    }
  }

  String get _instruction {
    if (_successMessage != null) return _successMessage!;
    return switch (_step) {
      _Step.moveRotateDrop => _readyToDrop
          ? 'Now press Space to drop it.'
          : 'Move it (← / →) and rotate it (↑ or Q).',
      _Step.mirror =>
        "This piece won't fuse as-is — press M to mirror it, then Space to drop it.",
      _Step.fusion =>
        'Mirror it (M), then drop it (Space) anywhere on the bottom row to fuse it.',
      _Step.hold => 'Press C to hold this piece for later.',
      _Step.cavityFill => 'Press G to instantly fill that stray gap.',
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
          child: Column(
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
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _config.cols / _config.rows,
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
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
