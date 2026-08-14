import 'dart:math';

/// Tick-duration curves. Both decay smoothly toward [floorMs] with no early
/// hard ceiling, so difficulty keeps escalating for as long as you survive.
/// Arcade starts faster and escalates more steeply than Classic by default —
/// felt from piece one, on top of its optional manual speed-boost stacking —
/// while Classic stays the steady, predictable baseline.
class SpeedCurve {
  const SpeedCurve._();

  static const int floorMs = 50;

  static const int _classicStartMs = 700;
  static const double _classicDecay = 0.87;

  static const int _arcadeStartMs = 600;
  static const double _arcadeDecay = 0.80;

  /// A real ceiling, unlike Classic/Arcade: eases off the same way Classic
  /// does but never drops below [_chillFloorMs], so the curve plateaus
  /// instead of becoming a wall for new/casual players (docs/GDD.md SS5).
  static const int _chillFloorMs = 300;

  static Duration classic(int level, int speedBoost) =>
      _curve(level, _classicStartMs, _classicDecay);

  static Duration chill(int level, int speedBoost) {
    final ms = _curve(
      level,
      _classicStartMs,
      _classicDecay,
    ).inMilliseconds.clamp(_chillFloorMs, _classicStartMs);
    return Duration(milliseconds: ms);
  }

  /// A constant tick duration with no escalation at all — used by Sprint
  /// (fixed pace, the clock is the challenge) and Zen (slow, never ramps).
  static Duration Function(int level, int speedBoost) fixed(int ms) {
    return (level, speedBoost) => Duration(milliseconds: ms);
  }

  static Duration arcade(int level, int speedBoost) {
    final base = _curve(
      level,
      _arcadeStartMs,
      _arcadeDecay,
    ).inMilliseconds.toDouble();
    final boosted = (base / (1 + speedBoost * 0.2)).clamp(
      floorMs.toDouble(),
      base,
    );
    return Duration(milliseconds: boosted.round());
  }

  static Duration _curve(int level, int startMs, double decayRate) {
    final ms = floorMs + (startMs - floorMs) * pow(decayRate, level - 1);
    return Duration(milliseconds: ms.round().clamp(floorMs, startMs));
  }
}
