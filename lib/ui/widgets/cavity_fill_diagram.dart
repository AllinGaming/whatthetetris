import 'package:flutter/material.dart';

import '../../game/tri_paint.dart';
import '../../models/piece.dart';

/// A tap-to-fill diagram for the tutorial: a lone, unfused triangle half
/// (the "cavity") on the left, the same cell self-completed in its own
/// color on the right — Cavity Fill doesn't borrow a color from anywhere
/// else, it just closes the gap. The player taps the cavity to close it
/// themselves, the same way they'd press G.
class CavityFillDiagram extends StatefulWidget {
  const CavityFillDiagram({super.key, required this.color, this.size = 56});

  final Color color;
  final double size;

  @override
  State<CavityFillDiagram> createState() => _CavityFillDiagramState();
}

class _CavityFillDiagramState extends State<CavityFillDiagram> {
  bool _filled = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _filled = !_filled),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _CavityCellPainter(
                    color: widget.color,
                    filled: false,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _filled ? 1 : 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: 0.85 + 0.15 * scale, child: child),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _CavityCellPainter(
                      color: widget.color,
                      filled: _filled,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _filled ? 'Tap to reset' : 'Tap to fill it',
            style: TextStyle(
              color: widget.color.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CavityCellPainter extends CustomPainter {
  _CavityCellPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    if (filled) {
      paintFullCell(canvas, rect, color, glow: 0.2);
    } else {
      paintTriHalf(canvas, rect, TriHalf.bl, color, glow: 0.1);
    }
  }

  @override
  bool shouldRepaint(covariant _CavityCellPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}
