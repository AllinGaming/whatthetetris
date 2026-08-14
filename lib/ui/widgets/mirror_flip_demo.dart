import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/tri_paint.dart';
import '../../models/piece.dart';

/// A tap-to-flip demo for the tutorial showing what Mirror Flip actually
/// does: every cell of a piece swaps its triangle-half assignment (bl <->
/// tr) simultaneously, in place — no move, no rotation. Both cells share one
/// color because it's one piece, not two fusing together (that story
/// belongs to [FusionHero] on the Fusion page). The player taps it
/// themselves rather than watching it loop, the same way they'd press M.
class MirrorFlipDemo extends StatefulWidget {
  const MirrorFlipDemo({
    super.key,
    required this.color,
    this.size = 112,
    this.reduceMotion = false,
  });

  final Color color;
  final double size;

  /// The app's own Accessibility > "Reduce motion" toggle
  /// (`SettingsService.reduceMotion`) — distinct from, and checked in
  /// addition to, the OS-level `MediaQuery.disableAnimations` flag, since a
  /// player can turn one on without the other.
  final bool reduceMotion;

  @override
  State<MirrorFlipDemo> createState() => _MirrorFlipDemoState();
}

class _MirrorFlipDemoState extends State<MirrorFlipDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..addListener(_onTick);
  bool _mirrored = false;

  /// Guards against toggling [_mirrored] more than once per run as
  /// [_controller] ticks past the midpoint — `addListener` fires on every
  /// tick, not just the one where it first crosses 0.5.
  bool _crossedMidpoint = false;

  bool get _skipMotion =>
      widget.reduceMotion || MediaQuery.of(context).disableAnimations;

  void _onTick() {
    if (!_crossedMidpoint && _controller.value >= 0.5) {
      _crossedMidpoint = true;
      setState(() => _mirrored = !_mirrored);
    }
    if (_controller.isCompleted) {
      // Always plays 0->1 forward, then snaps straight back to the resting
      // angle-0 frame — a full rotateY(pi) at rest would visually cancel
      // out with the just-toggled content and look unchanged, so the
      // "turn" only exists while actually mid-flight.
      _controller.value = 0;
      _crossedMidpoint = false;
    }
  }

  void _toggle() {
    if (_controller.isAnimating) return;
    if (_skipMotion) {
      setState(() => _mirrored = !_mirrored);
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: widget.size * 0.62,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final angle = _controller.value * pi;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      child: CustomPaint(
                        painter: _MirrorFlipPainter(
                          mirrored: _mirrored,
                          color: widget.color,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to flip',
                style: TextStyle(
                  color: widget.color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MirrorFlipPainter extends CustomPainter {
  _MirrorFlipPainter({required this.mirrored, required this.color});

  final bool mirrored;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height;
    final gap = cell * 0.18;
    final totalWidth = cell * 2 + gap;
    final left = (size.width - totalWidth) / 2;
    final rectA = Rect.fromLTWH(left, 0, cell, cell);
    final rectB = Rect.fromLTWH(left + cell + gap, 0, cell, cell);
    final triA = mirrored ? TriHalf.tr : TriHalf.bl;
    final triB = mirrored ? TriHalf.bl : TriHalf.tr;
    paintTriHalf(canvas, rectA, triA, color, glow: 0.15);
    paintTriHalf(canvas, rectB, triB, color, glow: 0.15);
  }

  @override
  bool shouldRepaint(covariant _MirrorFlipPainter oldDelegate) =>
      oldDelegate.mirrored != mirrored || oldDelegate.color != color;
}
