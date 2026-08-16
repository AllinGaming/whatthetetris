import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Interprets raw pointer events on the board into this game's touch
/// vocabulary: drag left/right to move, drag down to soft-drop, a fast
/// downward fling to hard-drop, a fast upward swipe to rotate, a tap, a
/// long-press to hold, and a quick second tap (a lightweight "double-tap")
/// as a bonus hard-drop shortcut.
///
/// Deliberately built on [Listener] (raw pointer events) rather than
/// stacking [GestureDetector]'s onTapUp/onDoubleTap/onLongPress/onPan* on
/// one widget. Those recognizers all compete in Flutter's gesture arena for
/// the same pointer: LongPress self-cancels on the slightest jitter (which
/// Pan's own activation slop practically guarantees before the long-press
/// deadline), DoubleTap forces every plain tap to wait out its timeout, and
/// a tap can be pre-empted by Pan winning the arena first. Interpreting the
/// stream ourselves sidesteps all of that -- every event always reaches
/// this controller, so nothing gets stolen or delayed by a competitor.
class BoardGestureController {
  BoardGestureController({
    required this.getCellSize,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onSoftDrop,
    required this.onSwipeUp,
    required this.onFlingDown,
    required this.onLongPress,
    required this.onTap,
    required this.onQuickDoubleTap,
    this.dragLockThreshold = 8.0,
    this.flingDownVelocity = 1200.0,
    this.swipeUpVelocity = 700.0,
    this.longPressDuration = const Duration(milliseconds: 450),
    this.doubleTapWindow = const Duration(milliseconds: 250),
    this.doubleTapSlop = 30.0,
  });

  /// The board's current on-screen cell size in logical pixels, read live
  /// (rather than passed once) since it's only known after layout and can
  /// change with the window.
  final double Function() getCellSize;

  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onSoftDrop;

  /// Callers gate this on their own touch-control-scheme check (swipe-up
  /// rotate is a gestures-scheme-only affordance; the buttons scheme
  /// already rotates via tap) rather than this controller knowing about
  /// schemes at all.
  final VoidCallback onSwipeUp;

  final VoidCallback onFlingDown;
  final VoidCallback onLongPress;

  /// Fired immediately on release for a pointer that never turned into a
  /// drag or a long-press -- no artificial delay, unlike waiting out
  /// [GestureDetector]'s double-tap timeout.
  final ValueChanged<Offset> onTap;

  /// Fired in addition to [onTap] when a second tap lands within
  /// [doubleTapWindow] and [doubleTapSlop] of the previous one. Callers
  /// gate this on their own scheme check, same as [onSwipeUp].
  final VoidCallback onQuickDoubleTap;

  final double dragLockThreshold;
  final double flingDownVelocity;
  final double swipeUpVelocity;
  final Duration longPressDuration;
  final Duration doubleTapWindow;
  final double doubleTapSlop;

  int? _pointer;
  Offset _lastPosition = Offset.zero;
  double _dragDx = 0;
  double _dragDy = 0;
  bool? _dragHorizontal;
  bool _longPressFired = false;
  Timer? _longPressTimer;
  VelocityTracker? _velocityTracker;

  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  void handlePointerDown(PointerDownEvent event) {
    if (_pointer != null) return; // single-touch only, first pointer wins.
    _pointer = event.pointer;
    _lastPosition = event.localPosition;
    _dragDx = 0;
    _dragDy = 0;
    _dragHorizontal = null;
    _longPressFired = false;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _longPressTimer?.cancel();
    _longPressTimer = Timer(longPressDuration, () {
      _longPressFired = true;
      onLongPress();
    });
  }

  void handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    // The long-press already fired -- this gesture is spent, matching how
    // a winning LongPressGestureRecognizer would leave Pan no further
    // updates for the same pointer.
    if (_longPressFired) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final dx = event.localPosition.dx - _lastPosition.dx;
    final dy = event.localPosition.dy - _lastPosition.dy;
    _lastPosition = event.localPosition;
    _dragDx += dx;
    _dragDy += dy;

    final wasLocked = _dragHorizontal != null;
    _dragHorizontal ??=
        (_dragDx.abs() >= dragLockThreshold ||
            _dragDy.abs() >= dragLockThreshold)
        ? _dragDx.abs() >= _dragDy.abs()
        : null;
    if (!wasLocked && _dragHorizontal != null) {
      // Just resolved into a real drag -- no longer a long-press or tap
      // candidate.
      _longPressTimer?.cancel();
    }

    final cellSize = getCellSize();
    if (cellSize <= 0) return;
    if (_dragHorizontal == true) {
      while (_dragDx >= cellSize) {
        onMoveRight();
        _dragDx -= cellSize;
      }
      while (_dragDx <= -cellSize) {
        onMoveLeft();
        _dragDx += cellSize;
      }
    } else if (_dragHorizontal == false) {
      while (_dragDy >= cellSize) {
        onSoftDrop();
        _dragDy -= cellSize;
      }
      if (_dragDy < 0) _dragDy = 0; // dragging back up never moves it up
    }
  }

  void handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _longPressTimer?.cancel();
    final wasLongPress = _longPressFired;
    final dragHorizontal = _dragHorizontal;
    final velocity = _velocityTracker?.getVelocity();
    _reset();

    if (wasLongPress) return; // hold already fired; nothing else to do.

    if (dragHorizontal == true) return; // a horizontal move release.
    if (dragHorizontal == false) {
      final dy = velocity?.pixelsPerSecond.dy ?? 0;
      if (dy > flingDownVelocity) {
        onFlingDown();
      } else if (dy < -swipeUpVelocity) {
        onSwipeUp();
      }
      return;
    }

    // Never resolved into a drag -- a genuine tap.
    onTap(event.localPosition);
    _registerTapForDoubleTap(event.localPosition);
  }

  void handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _longPressTimer?.cancel();
    _reset();
  }

  void _registerTapForDoubleTap(Offset position) {
    final now = DateTime.now();
    final lastTime = _lastTapTime;
    final lastPosition = _lastTapPosition;
    if (lastTime != null &&
        lastPosition != null &&
        now.difference(lastTime) <= doubleTapWindow &&
        (position - lastPosition).distance <= doubleTapSlop) {
      _lastTapTime = null;
      _lastTapPosition = null;
      onQuickDoubleTap();
      return;
    }
    _lastTapTime = now;
    _lastTapPosition = position;
  }

  void _reset() {
    _pointer = null;
    _dragDx = 0;
    _dragDy = 0;
    _dragHorizontal = null;
    _longPressFired = false;
    _velocityTracker = null;
  }

  void dispose() {
    _longPressTimer?.cancel();
  }
}
