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
import 'board_gesture_controller.dart';
import 'board_painter.dart';
import 'game_animations.dart';
import 'game_board.dart';

enum _Step { moveRotateDrop, fusion, hold, cavityFill, done }

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

  late GameBoard _board;
  late final GameAnimations _anim = GameAnimations(vsync: this);
  final _boardStaticCache = BoardStaticCache();
  final _focusNode = FocusNode();

  /// Same [BoardGestureController] [GameScreen] uses for its board gestures,
  /// so drag/swipe/fling/hold feel identical here and in a real run.
  late final _boardGestures = BoardGestureController(
    getCellSize: () => _cellSize,
    onMoveLeft: () => _move(-1, 0),
    onMoveRight: () => _move(1, 0),
    onSoftDrop: () => _move(0, 1),
    onSwipeUp: _handleBoardSwipeUp,
    onFlingDown: _hardDrop,
    onLongPress: _hold,
    onTap: _handleBoardTap,
    onQuickDoubleTap: _handleBoardQuickDoubleTap,
  );

  double _cellSize = 1;

  _Step _step = _Step.moveRotateDrop;
  ActivePiece? _active;
  bool _movedOnce = false;
  bool _rotatedOnce = false;
  bool _readyToDrop = false;
  int _cavityCharges = 0;
  String? _successMessage;
  String? _oopsMessage;
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
    _boardGestures.dispose();
    super.dispose();
  }

  Future<void> _haptic(Future<void> Function() feedback) async {
    if (!widget.settings.hapticsEnabled) return;
    await feedback();
  }

  /// The active piece's on-screen center, in grid units -- where a burst or
  /// impact ring for whatever it just did should originate.
  Offset _pieceCenter(ActivePiece piece) {
    final cells = piece.cellsOnBoard();
    final col = cells.map((c) => c.col).reduce((a, b) => a + b) / cells.length;
    final row = cells.map((c) => c.row).reduce((a, b) => a + b) / cells.length;
    return Offset(col + 0.5, row + 0.5);
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
    unawaited(_haptic(HapticFeedback.selectionClick));
    _anim.burst(_pieceCenter(toggled), _theme.accent, count: 7);
    setState(() {});
  }

  void _hold() {
    // Only wired during its own step -- a full swap-back model isn't needed
    // just to teach "press C to set a piece aside."
    if (_step != _Step.hold || _active == null) return;
    unawaited(_haptic(HapticFeedback.mediumImpact));
    _anim.burst(_pieceCenter(_active!), _theme.accent, count: 9);
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
    final origin = _pieceCenter(candidate);
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
    _anim.triggerImpactRing(origin);
    _anim.triggerShake(intensity: fusions > 0 ? 1.4 : 1.0);
    unawaited(
      _haptic(
        fusions > 0 ? HapticFeedback.heavyImpact : HapticFeedback.mediumImpact,
      ),
    );
    // A fusion is this game's whole hook -- worth a bigger, more colorful
    // payoff than an ordinary lock, scaled up further per extra fusion.
    if (fusions > 0) {
      _anim.burst(origin, _theme.accent, count: 10 + fusions * 6);
    }
    _active = null;
    setState(() {});
    _onLocked(fusions: fusions);
  }

  void _onLocked({required int fusions}) {
    switch (_step) {
      case _Step.moveRotateDrop:
        _completeStep();
      case _Step.fusion:
        if (fusions >= 1) {
          _completeStep();
        } else {
          _setupStep(_Step.fusion);
        }
      case _Step.hold:
        // Dropping instead of holding would otherwise strand the player --
        // no active piece left, and nothing in this step reacts to a lock --
        // so nudge them and give them a fresh piece to actually hold.
        _advanceTimer?.cancel();
        setState(
          () => _oopsMessage = 'Try Hold instead — that piece is gone now.',
        );
        _advanceTimer = Timer(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          _oopsMessage = null;
          _setupStep(_Step.hold);
        });
      case _Step.cavityFill:
      case _Step.done:
        break;
    }
  }

  void _completeStep() {
    unawaited(_haptic(HapticFeedback.mediumImpact));
    _anim.burst(
      Offset(_config.cols / 2, _config.rows * 0.35),
      _theme.accent,
      count: 14,
    );
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

  /// Swipe-up-to-rotate is a gestures-scheme-only affordance -- the buttons
  /// scheme already rotates via tap, so a stray upward swipe there
  /// shouldn't also rotate.
  void _handleBoardSwipeUp() {
    if (_gestureScheme) _rotate(1);
  }

  /// A quick second tap near the first is a bonus hard-drop shortcut, but
  /// only under the gestures scheme -- under buttons, tap already rotates,
  /// and two quick taps there should just rotate twice, not hard-drop.
  void _handleBoardQuickDoubleTap() {
    if (_gestureScheme) _hardDrop();
  }

  String get _instruction {
    if (_successMessage != null) return _successMessage!;
    if (_oopsMessage != null) return _oopsMessage!;
    return switch (_step) {
      _Step.moveRotateDrop =>
        _readyToDrop ? 'Now drop it!' : 'Move it, then rotate it.',
      _Step.fusion =>
        'Mirror it, then drop it anywhere on the bottom row to fuse it.',
      _Step.hold => 'Hold this piece for later.',
      _Step.cavityFill => 'Fill that stray gap.',
      _Step.done => "You're ready — go play!",
    };
  }

  /// What the player needs to do right now, spelled out as concrete inputs
  /// rather than left implicit in the instruction text -- one entry per
  /// distinct action (e.g. move-then-rotate is two entries, shown together).
  List<_ActionHint> get _currentHints {
    switch (_step) {
      case _Step.moveRotateDrop:
        if (!_readyToDrop) {
          return const [
            _ActionHint(
              keys: ['←', '→'],
              icon: Icons.swap_horiz,
              label: 'Move',
              gesture: _Gesture.dragHorizontal,
            ),
            _ActionHint(
              keys: ['↑', 'Q'],
              icon: Icons.rotate_right,
              label: 'Rotate',
              gesture: _Gesture.swipeUp,
            ),
          ];
        }
        return const [
          _ActionHint(
            keys: ['Space'],
            icon: Icons.keyboard_double_arrow_down,
            label: 'Drop',
            gesture: _Gesture.swipeDown,
          ),
        ];
      case _Step.fusion:
        return const [
          _ActionHint(
            keys: ['M'],
            icon: Icons.flip,
            label: 'Mirror',
            gesture: _Gesture.tapOnce,
          ),
          _ActionHint(
            keys: ['Space'],
            icon: Icons.keyboard_double_arrow_down,
            label: 'Drop',
            gesture: _Gesture.swipeDown,
          ),
        ];
      case _Step.hold:
        return const [
          _ActionHint(
            keys: ['C'],
            icon: Icons.inventory_2_outlined,
            label: 'Hold',
            gesture: _Gesture.longPress,
          ),
        ];
      case _Step.cavityFill:
        return const [
          _ActionHint(
            keys: ['G'],
            icon: Icons.auto_fix_high,
            label: 'Fill',
            gesture: _Gesture.tapOnce,
          ),
        ];
      case _Step.done:
        return const [];
    }
  }

  /// Spells out exactly which key/button/gesture the current step needs --
  /// a keyboard glyph on desktop, the matching D-pad icon (pulsing, so it's
  /// easy to spot against the real pad below) under the buttons scheme, or a
  /// small looping animation of the actual gesture under the gestures
  /// scheme, since there's no pad to point at there.
  Widget _buildControlHints(bool mobile) {
    final hints = _currentHints;
    if (hints.isEmpty) return const SizedBox.shrink();
    final scheme = !mobile
        ? _HintScheme.keyboard
        : (_gestureScheme ? _HintScheme.gestures : _HintScheme.buttons);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 8,
        children: [for (final hint in hints) _buildHintChip(hint, scheme)],
      ),
    );
  }

  Widget _buildHintChip(_ActionHint hint, _HintScheme scheme) {
    final accent = _theme.accent;
    final reduceMotion = widget.settings.reduceMotion;
    return Column(
      key: ValueKey('${_step.name}-${hint.label}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        switch (scheme) {
          _HintScheme.keyboard => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < hint.keys.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      '/',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                _KeyCap(label: hint.keys[i], accent: accent),
              ],
            ],
          ),
          _HintScheme.buttons => _IconPulse(
            icon: hint.icon,
            accent: accent,
            reduceMotion: reduceMotion,
          ),
          _HintScheme.gestures => _GestureGlyph(
            gesture: hint.gesture,
            accent: accent,
            reduceMotion: reduceMotion,
          ),
        },
        const SizedBox(height: 4),
        Text(
          hint.label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
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
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(_instruction),
                            tween: Tween(
                              begin: _successMessage != null ? 1.3 : 1.0,
                              end: 1.0,
                            ),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) => Transform.scale(
                              alignment: Alignment.centerLeft,
                              scale: scale,
                              child: child,
                            ),
                            child: Text(
                              _instruction,
                              style: TextStyle(
                                color: _successMessage != null
                                    ? Colors.greenAccent
                                    : _oopsMessage != null
                                    ? Colors.orangeAccent
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                shadows: neonShadows(accent, intensity: 0.5),
                              ),
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
                  _buildControlHints(mobile),
                  const SizedBox(height: 10),
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
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _boardGestures.handlePointerDown,
              onPointerMove: _boardGestures.handlePointerMove,
              onPointerUp: _boardGestures.handlePointerUp,
              onPointerCancel: _boardGestures.handlePointerCancel,
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
      // The cavity-fill step never spawns a piece (there's nothing to
      // move/rotate/hold), so _canAct is false there -- but the Fill
      // button itself still needs to be tappable, or mobile players on
      // the buttons scheme have no way to complete this step at all.
      enabled: _canAct || _step == _Step.cavityFill,
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
    final reduceMotion = widget.settings.reduceMotion;
    return Scaffold(
      backgroundColor: _theme.backgroundBottom,
      body: SafeArea(
        child: Stack(
          children: [
            if (!reduceMotion)
              Positioned.fill(
                child: _ConfettiOverlay(
                  colors: [
                    _theme.colorFor('T4'),
                    _theme.colorFor('S4'),
                    _theme.colorFor('L4'),
                    _theme.colorFor('O4'),
                    _theme.colorFor('I4'),
                  ],
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 550),
                      curve: reduceMotion ? Curves.linear : Curves.elasticOut,
                      builder: (context, t, child) =>
                          Transform.scale(scale: t, child: child),
                      child: Icon(Icons.check_circle, size: 72, color: accent),
                    ),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (context, t, child) =>
                          Opacity(opacity: t, child: child),
                      child: Text(
                        "You're ready — go play!",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          shadows: neonShadows(accent),
                        ),
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
          ],
        ),
      ),
    );
  }
}

/// A one-shot confetti shower for the tutorial's finish screen -- pieces
/// borrow this game's own tetromino colors rather than generic party
/// colors, so the celebration still reads as "this game," not a stock
/// effect. Skipped entirely under reduced motion (see [_buildDone]).
class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay({required this.colors});

  final List<Color> colors;

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final List<_ConfettiPiece> _pieces = _build();

  List<_ConfettiPiece> _build() {
    final rand = Random();
    return List.generate(26, (_) {
      return _ConfettiPiece(
        x: rand.nextDouble(),
        delay: rand.nextDouble() * 0.25,
        speed: 0.75 + rand.nextDouble() * 0.55,
        drift: (rand.nextDouble() - 0.5) * 0.5,
        rotationSpeed: (rand.nextDouble() - 0.5) * 8,
        size: 6 + rand.nextDouble() * 6,
        color: widget.colors[rand.nextInt(widget.colors.length)],
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(t: _ctrl.value, pieces: _pieces),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });

  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double rotationSpeed;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.pieces});

  final double t;
  final List<_ConfettiPiece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final y = size.height * 0.1 + size.height * 0.85 * localT * p.speed;
      final x = size.width * p.x + sin(localT * pi * 2) * size.width * p.drift;
      final fadeOut = localT > 0.8 ? (1 - localT) / 0.2 : 1.0;
      final paint = Paint()
        ..color = p.color.withValues(alpha: fadeOut.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(localT * p.rotationSpeed);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Which input surface [_buildHintChip] renders for -- picked from the
/// viewport width and [SettingsService.touchControlScheme], same split the
/// rest of this screen (and [GameScreen]) already uses for real input.
enum _HintScheme { keyboard, buttons, gestures }

/// The shapes a touch gesture hint can animate -- one [_GestureGlyph] loop
/// per member, see its painter.
enum _Gesture { tapOnce, swipeDown, longPress, swipeUp, dragHorizontal }

/// One taught action: the key(s) that trigger it, the icon its D-pad button
/// wears (for the buttons-scheme hint), and which [_Gesture] mimics it.
class _ActionHint {
  const _ActionHint({
    required this.keys,
    required this.icon,
    required this.label,
    required this.gesture,
  });

  final List<String> keys;
  final IconData icon;
  final String label;
  final _Gesture gesture;
}

/// A small "keyboard key" chip -- shows the player exactly which key to
/// press instead of leaving it to the instruction text's prose.
class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 6),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// A gently breathing icon matching one of [TouchDpad]'s own button icons --
/// under the buttons scheme, this is the cue to look for that icon on the
/// real pad below rather than a full gesture demo (there's no gesture to
/// demonstrate; the action is a tap on a fixed button).
class _IconPulse extends StatefulWidget {
  const _IconPulse({
    required this.icon,
    required this.accent,
    required this.reduceMotion,
  });

  final IconData icon;
  final Color accent;
  final bool reduceMotion;

  @override
  State<_IconPulse> createState() => _IconPulseState();
}

class _IconPulseState extends State<_IconPulse>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;

  /// Checked in addition to [_IconPulse.reduceMotion] -- a test disabling
  /// animations at the OS level (rather than through this app's own
  /// setting) must still stop this loop, or `pumpAndSettle` never quiesces.
  bool get _skipMotion =>
      widget.reduceMotion || MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deferred to here (needs MediaQuery) rather than initState, guarded by
    // _started since didChangeDependencies can re-fire. Touching _ctrl
    // unconditionally forces its lazy construction now, while safely
    // mounted -- see touch_dpad.dart's _PulsingGlowState for why leaving
    // dispose() as the first access (when this never turns on) crashes.
    if (!_started) {
      _started = true;
      final ctrl = _ctrl;
      if (!_skipMotion) ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _skipMotion ? 0.0 : _ctrl.value;
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accent.withValues(alpha: 0.14 + 0.12 * t),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.5 + 0.3 * t),
              width: 1.5,
            ),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 18),
        );
      },
    );
  }
}

/// A small looping animation of the actual touch gesture the current step
/// needs -- a tap ripple, a double-tap, a long-press fill ring, an upward
/// swipe, or a left-right drag -- so a gestures-scheme player sees exactly
/// what to do rather than guessing from text alone.
class _GestureGlyph extends StatefulWidget {
  const _GestureGlyph({
    required this.gesture,
    required this.accent,
    required this.reduceMotion,
  });

  final _Gesture gesture;
  final Color accent;
  final bool reduceMotion;

  @override
  State<_GestureGlyph> createState() => _GestureGlyphState();
}

class _GestureGlyphState extends State<_GestureGlyph>
    with SingleTickerProviderStateMixin {
  static Duration _durationFor(_Gesture g) => switch (g) {
    _Gesture.tapOnce => const Duration(milliseconds: 1000),
    _Gesture.swipeDown => const Duration(milliseconds: 1100),
    _Gesture.longPress => const Duration(milliseconds: 1400),
    _Gesture.swipeUp => const Duration(milliseconds: 1100),
    _Gesture.dragHorizontal => const Duration(milliseconds: 1600),
  };

  late final _ctrl = AnimationController(
    vsync: this,
    duration: _durationFor(widget.gesture),
  );

  static IconData _staticIconFor(_Gesture g) => switch (g) {
    _Gesture.tapOnce => Icons.touch_app,
    _Gesture.swipeDown => Icons.swipe_down_alt,
    _Gesture.longPress => Icons.touch_app,
    _Gesture.swipeUp => Icons.swipe_up_alt,
    _Gesture.dragHorizontal => Icons.swipe,
  };

  bool _started = false;

  /// See _IconPulseState._skipMotion -- same reasoning applies here.
  bool get _skipMotion =>
      widget.reduceMotion || MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final ctrl = _ctrl;
      if (!_skipMotion) ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_skipMotion) {
      return SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          _staticIconFor(widget.gesture),
          color: widget.accent,
          size: 20,
        ),
      );
    }
    return SizedBox(
      width: 40,
      height: 40,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _GesturePainter(
            t: _ctrl.value,
            gesture: widget.gesture,
            color: widget.accent,
          ),
        ),
      ),
    );
  }
}

class _GesturePainter extends CustomPainter {
  _GesturePainter({
    required this.t,
    required this.gesture,
    required this.color,
  });

  final double t;
  final _Gesture gesture;
  final Color color;

  void _paintRipple(Canvas canvas, Size size, double localT) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2 - 2;
    final r = maxR * 0.35 + maxR * 0.65 * localT;
    final alpha = (1 - localT).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.55 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, maxR * 0.16, Paint()..color = color);
  }

  void _paintLongPress(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2 - 2;
    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxR),
      -pi / 2,
      2 * pi * t,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, maxR * 0.16, Paint()..color = color);
  }

  void _paintSwipeUp(Canvas canvas, Size size) {
    final x = size.width / 2;
    final travel = size.height - 8;
    final y = size.height - 4 - travel * t;
    final fadeIn = (t / 0.15).clamp(0.0, 1.0);
    final fadeOut = ((1 - t) / 0.15).clamp(0.0, 1.0);
    final alpha = fadeIn < fadeOut ? fadeIn : fadeOut;
    final paint = Paint()..color = color.withValues(alpha: alpha);
    canvas.drawCircle(Offset(x, y), 3.5, paint);
    final arrow = Path()
      ..moveTo(x - 6, y + 9)
      ..lineTo(x, y)
      ..lineTo(x + 6, y + 9);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintSwipeDown(Canvas canvas, Size size) {
    final x = size.width / 2;
    final travel = size.height - 8;
    final y = 4 + travel * t;
    final fadeIn = (t / 0.15).clamp(0.0, 1.0);
    final fadeOut = ((1 - t) / 0.15).clamp(0.0, 1.0);
    final alpha = fadeIn < fadeOut ? fadeIn : fadeOut;
    final paint = Paint()..color = color.withValues(alpha: alpha);
    canvas.drawCircle(Offset(x, y), 3.5, paint);
    final arrow = Path()
      ..moveTo(x - 6, y - 9)
      ..lineTo(x, y)
      ..lineTo(x + 6, y - 9);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintDragHorizontal(Canvas canvas, Size size) {
    final y = size.height / 2;
    final left = size.width * 0.18;
    final right = size.width * 0.82;
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 2,
    );
    final ping = (sin(2 * pi * t) + 1) / 2;
    final x = left + (right - left) * ping;
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (gesture) {
      case _Gesture.tapOnce:
        _paintRipple(canvas, size, t);
      case _Gesture.swipeDown:
        _paintSwipeDown(canvas, size);
      case _Gesture.longPress:
        _paintLongPress(canvas, size);
      case _Gesture.swipeUp:
        _paintSwipeUp(canvas, size);
      case _Gesture.dragHorizontal:
        _paintDragHorizontal(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _GesturePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.gesture != gesture ||
      oldDelegate.color != color;
}
