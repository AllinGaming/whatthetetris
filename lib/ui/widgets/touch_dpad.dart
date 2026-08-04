import 'package:flutter/material.dart';

import 'hold_repeat_button.dart';
import 'juicy_button.dart';

/// The mobile on-screen control pad: a movement cluster (left/right/down,
/// hold-to-repeat) and an action cluster (rotate/mirror/hard-drop, single
/// fire per tap — these must NOT repeat, especially hard-drop). Wrapped in
/// a horizontal scroll as a safety net so it never overflows on the
/// narrowest phone widths, but sized to fit without scrolling on anything
/// phone-sized and up.
class TouchDpad extends StatelessWidget {
  const TouchDpad({
    super.key,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onSoftDrop,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onMirror,
    required this.onHardDrop,
  });

  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onSoftDrop;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onMirror;
  final VoidCallback onHardDrop;

  static const _dotSize = 42.0;

  Widget _dot(BuildContext context, IconData icon, {Color? color}) {
    final tint = color ?? Colors.white;
    return Container(
      width: _dotSize,
      height: _dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.10),
        border: Border.all(color: tint.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(color: tint.withValues(alpha: 0.25), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: tint, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HoldRepeatButton(
              onHold: onMoveLeft,
              child: _dot(context, Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            HoldRepeatButton(
              onHold: onSoftDrop,
              child: _dot(context, Icons.arrow_downward),
            ),
            const SizedBox(width: 8),
            HoldRepeatButton(
              onHold: onMoveRight,
              child: _dot(context, Icons.arrow_forward),
            ),
            const SizedBox(width: 28),
            JuicyButton(
              onPressed: onRotateLeft,
              style: _circleStyle,
              child: const Icon(Icons.rotate_left, size: 20),
            ),
            const SizedBox(width: 8),
            JuicyButton(
              onPressed: onRotateRight,
              style: _circleStyle,
              child: const Icon(Icons.rotate_right, size: 20),
            ),
            const SizedBox(width: 8),
            JuicyButton(
              onPressed: onMirror,
              style: _circleStyle,
              child: const Icon(Icons.flip, size: 18),
            ),
            const SizedBox(width: 8),
            JuicyButton(
              onPressed: onHardDrop,
              style: _circleStyle.copyWith(
                foregroundColor: WidgetStatePropertyAll(accent),
              ),
              child: const Icon(Icons.vertical_align_bottom, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  static final ButtonStyle _circleStyle = ElevatedButton.styleFrom(
    shape: const CircleBorder(),
    minimumSize: const Size(_dotSize, _dotSize),
    fixedSize: const Size(_dotSize, _dotSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: EdgeInsets.zero,
    backgroundColor: Colors.white10,
    foregroundColor: Colors.white,
    elevation: 0,
  );
}
