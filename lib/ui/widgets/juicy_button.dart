import 'package:flutter/material.dart';

/// Wraps a button with a small press-down scale for tactile feedback. Uses
/// [Listener] (not [GestureDetector]) so it only observes raw pointer events
/// and never competes with the button's own tap recognizer.
class JuicyButton extends StatefulWidget {
  const JuicyButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  State<JuicyButton> createState() => _JuicyButtonState();
}

class _JuicyButtonState extends State<JuicyButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    // Only guards against showing press feedback on a disabled button --
    // must NOT also block the release/cancel reset, or a button that gets
    // disabled by its own onPressed (e.g. Hard Drop ending the game)
    // between pointer-down and pointer-up gets stuck permanently scaled
    // down, since onPressed is already null by the time the reset fires.
    if (value && widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: widget.style,
          child: widget.child,
        ),
      ),
    );
  }
}
