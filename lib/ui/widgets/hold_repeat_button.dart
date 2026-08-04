import 'dart:async';

import 'package:flutter/material.dart';

/// A touch button that fires once immediately on press, then repeats at a
/// DAS-style rate while held — the touch equivalent of the OS auto-repeat a
/// held keyboard key already gets for free. Used only for directional
/// movement (left/right/down); rotate/hard-drop/mirror use [JuicyButton]
/// instead since they must fire once per tap, never repeat.
///
/// Uses [Listener], not [GestureDetector], so it never competes with — or
/// gets stolen by — any other tappable it's nested near.
class HoldRepeatButton extends StatefulWidget {
  const HoldRepeatButton({
    super.key,
    required this.onHold,
    required this.child,
    this.initialDelay = const Duration(milliseconds: 180),
    this.repeatInterval = const Duration(milliseconds: 50),
  });

  final VoidCallback onHold;
  final Widget child;
  final Duration initialDelay;
  final Duration repeatInterval;

  @override
  State<HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<HoldRepeatButton> {
  Timer? _initialTimer;
  Timer? _repeatTimer;
  bool _pressed = false;

  void _start(PointerDownEvent _) {
    widget.onHold();
    setState(() => _pressed = true);
    _initialTimer = Timer(widget.initialDelay, () {
      _repeatTimer = Timer.periodic(widget.repeatInterval, (_) => widget.onHold());
    });
  }

  void _stop([PointerEvent? _]) {
    _initialTimer?.cancel();
    _repeatTimer?.cancel();
    _initialTimer = null;
    _repeatTimer = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _initialTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _start,
      onPointerUp: _stop,
      onPointerCancel: _stop,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
