import 'dart:math';

import 'package:flutter/material.dart';

/// A single burst particle. Position/velocity are in grid units (same
/// coordinate space as [GameAnimations.piecePos]) so the painter converts
/// to pixels once, the same way it already does for the active piece.
class Particle {
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required double life,
    this.fadeFraction = 1,
  }) : life = life,
       maxLife = life;

  Offset position;
  Offset velocity;
  final Color color;
  double life;
  final double maxLife;
  final double fadeFraction;

  bool get isDead => life <= 0;
  double get opacity {
    final remaining = (life / maxLife).clamp(0.0, 1.0);
    final fadeWindow = fadeFraction.clamp(0.01, 1.0);
    return remaining >= fadeWindow
        ? 1
        : (remaining / fadeWindow).clamp(0.0, 1.0);
  }

  void advance(double dt) {
    position += velocity * dt;
    velocity += const Offset(0, 14) * dt; // gravity, in cells/s²
    velocity *= pow(0.35, dt).toDouble(); // drag
    life -= dt;
  }
}
