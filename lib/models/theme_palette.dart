import 'package:flutter/material.dart';

/// A swappable cosmetic unit: board background, per-piece colors, and the
/// accent used for glow/UI throughout the app (docs/GDD.md SS6.5). Free
/// themes ship in [all]; this is also the intended monetization surface
/// later (docs/MONETIZATION.md SS2.2) — nothing about *choosing* one is
/// gated, only future additional palettes would be.
@immutable
class ThemePalette {
  const ThemePalette({
    required this.id,
    required this.label,
    required this.pieceColors,
    required this.accent,
    required this.backgroundTop,
    required this.backgroundBottom,
    this.isColorblindSafe = false,
  });

  final String id;
  final String label;
  final Map<String, Color> pieceColors;
  final Color accent;
  final Color backgroundTop;
  final Color backgroundBottom;
  final bool isColorblindSafe;

  Color colorFor(String pieceName) =>
      pieceColors[pieceName] ?? const Color(0xFFFFFFFF);

  static const neon = ThemePalette(
    id: 'neon',
    label: 'Neon',
    accent: Color(0xFF66E0F4),
    backgroundTop: Color(0xFF0F131D),
    backgroundBottom: Color(0xFF0B0E14),
    pieceColors: {
      'I4': Color(0xFF8AE66E),
      'L4': Color(0xFF9B7BFF),
      'T4': Color(0xFFFF8FB1),
      'O4': Color(0xFFFFE066),
      'S4': Color(0xFF66E0F4),
      'Z4': Color(0xFFFF6E6E),
      'J4': Color(0xFF6E8CFF),
    },
  );

  /// Okabe-Ito-derived: chosen so all seven pieces stay distinguishable
  /// under protanopia/deuteranopia/tritanopia simulation, not just "looks
  /// fine" to unaffected eyes.
  static const colorblindSafe = ThemePalette(
    id: 'colorblind',
    label: 'Colorblind-Safe',
    isColorblindSafe: true,
    accent: Color(0xFFE8B000),
    backgroundTop: Color(0xFF12141A),
    backgroundBottom: Color(0xFF0B0C10),
    pieceColors: {
      'I4': Color(0xFF56B4E9), // sky blue
      'L4': Color(0xFFE69F00), // orange
      'T4': Color(0xFFCC79A7), // reddish purple
      'O4': Color(0xFFF0E442), // yellow
      'S4': Color(0xFF009E73), // bluish green
      'Z4': Color(0xFFD55E00), // vermillion
      'J4': Color(0xFF0072B2), // blue
    },
  );

  static const sunset = ThemePalette(
    id: 'sunset',
    label: 'Sunset',
    accent: Color(0xFFFF8A3D),
    backgroundTop: Color(0xFF1A1023),
    backgroundBottom: Color(0xFF120A18),
    pieceColors: {
      'I4': Color(0xFFFFB347),
      'L4': Color(0xFFFF6F59),
      'T4': Color(0xFFFF3D68),
      'O4': Color(0xFFFFD23D),
      'S4': Color(0xFFC65BCF),
      'Z4': Color(0xFFEF476F),
      'J4': Color(0xFF7B61FF),
    },
  );

  static const all = [neon, colorblindSafe, sunset];

  static ThemePalette byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => neon);
}
