import 'package:flutter/material.dart';

/// A stacked-shadow glow recipe reused for every neon-styled text element
/// (titles, toasts, the paused/game-over overlay). [intensity] scales both
/// blur and opacity so callers can dim it for secondary text.
List<Shadow> neonShadows(Color color, {double intensity = 1}) => [
  Shadow(color: color.withValues(alpha: 0.85 * intensity), blurRadius: 6),
  Shadow(color: color.withValues(alpha: 0.5 * intensity), blurRadius: 16),
  Shadow(color: Colors.black.withValues(alpha: 0.6 * intensity), blurRadius: 3),
];
