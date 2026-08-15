import 'package:flutter/material.dart';

import '../models/piece.dart';

/// Low-level triangle-half drawing shared by the board painter and the
/// next-piece preview, so the diagonal geometry is defined in exactly one
/// place.
Path triHalfPath(Rect rect, TriHalf tri) {
  final path = Path();
  switch (tri) {
    case TriHalf.bl:
      path
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.bottom);
      break;
    case TriHalf.tr:
      path
        ..moveTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.top);
      break;
  }
  return path..close();
}

// Reused across calls instead of allocating fresh Paint objects per triangle
// — this runs for every board cell on every animation frame (the falling
// piece alone keeps the board repainting continuously), so per-call
// allocation here was a real, constant GC/CPU cost during ordinary
// gameplay. Safe to share: each is fully reconfigured immediately before
// its single, synchronous `drawPath` call, and painting is single-threaded
// with no re-entrant/nested use of these functions.
final _glowPaint = Paint()..style = PaintingStyle.stroke;
final _fillPaint = Paint();
final _outlinePaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1;

/// Paints one triangle half. [glow] (0..1) brightens it toward white and
/// adds a colored neon halo behind it — used for the active piece's
/// permanent low glow and the brighter lock-flash/line-clear pulses.
void paintTriHalf(
  Canvas canvas,
  Rect rect,
  TriHalf tri,
  Color color, {
  double glow = 0,
  double opacity = 1,
}) {
  final path = triHalfPath(rect, tri);
  final lit = Color.lerp(color, Colors.white, glow * 0.85)!;

  if (glow > 0) {
    canvas.drawPath(
      path,
      _glowPaint
        ..strokeWidth = 2 + glow * 5
        ..color = color.withValues(alpha: 0.45 * glow * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + glow * 9),
    );
  }

  canvas.drawPath(
    path,
    _fillPaint
      ..shader = LinearGradient(
        colors: [
          lit.withValues(alpha: 0.95 * opacity),
          lit.withValues(alpha: 0.6 * opacity),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect),
  );
  canvas.drawPath(
    path,
    _outlinePaint
      ..color = Colors.white.withValues(alpha: (0.18 + glow * 0.4) * opacity),
  );
}

void paintFullCell(
  Canvas canvas,
  Rect rect,
  Color color, {
  double glow = 0,
  double opacity = 1,
}) {
  paintTriHalf(canvas, rect, TriHalf.bl, color, glow: glow, opacity: opacity);
  paintTriHalf(canvas, rect, TriHalf.tr, color, glow: glow, opacity: opacity);
}
