import 'dart:math';

import 'package:flutter/material.dart';

import 'particle.dart';

/// Owns the animation controllers that drive continuous motion on top of
/// the discrete grid simulation: smooth piece movement, a lock-flash pulse,
/// a line-clear flash, a hard-drop screen shake, and particle bursts.
class GameAnimations {
  GameAnimations({required TickerProvider vsync})
    : move = AnimationController(vsync: vsync),
      lockFlash = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 150),
      ),
      lineClear = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 280),
      ),
      shake = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 220),
      ),
      particles = AnimationController(
        vsync: vsync,
        duration: const Duration(seconds: 1),
      ),
      danger = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 650),
      ),
      impactRing = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 350),
      ),
      comboPulse = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 500),
      ),
      levelUp = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 700),
      ),
      celebration = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 1100),
      ) {
    // Used purely as a per-frame driver — its own 0..1 value is never read.
    particles.addListener(_advanceParticles);
  }

  final AnimationController move;
  final AnimationController lockFlash;
  final AnimationController lineClear;
  final AnimationController shake;
  final AnimationController particles;

  /// An expanding, fading ring at a hard drop's landing point — drawn by
  /// [BoardPainter] whenever [impactRing] is running. Grid-unit coordinates,
  /// same space as [piecePos].
  final AnimationController impactRing;
  Offset? impactRingOrigin;

  /// A soft pulsing glow around the board while a combo streak is alive —
  /// the combo equivalent of [danger]'s border pulse, so a chain reads as an
  /// ongoing event rather than just a series of toasts. Driven by
  /// [setComboHeat]; [comboHeat] (0..1) sets the glow's color/opacity, the
  /// controller itself just drives the pulse rhythm.
  final AnimationController comboPulse;
  double comboHeat = 0;

  /// A brief full-board flash when the player levels up, layered on top of
  /// the existing "LEVEL n!" toast/SFX. Triggered via [triggerLevelUp].
  final AnimationController levelUp;

  /// A slower, warmer full-board flash for a new personal best — longer and
  /// gentler than [levelUp] since it plays out while the game-over toast/SFX
  /// land, not mid-action. Triggered via [triggerCelebration].
  final AnimationController celebration;

  double _shakeIntensity = 1.0;

  /// A slow pulse (0..1..0) while the stack is in the danger zone
  /// (docs/GDD.md SS7) — started/stopped via [setDanger], never driven
  /// directly, so callers don't need to know it's a repeating animation.
  final AnimationController danger;
  bool _inDanger = false;

  /// When true, screen shake is suppressed and particle bursts are thinned
  /// out (docs/GDD.md SS8 accessibility pass) rather than fully disabled, so
  /// clears still read as distinct events.
  bool reduceMotion = false;

  final List<Particle> _particles = [];
  final _rand = Random();
  DateTime? _lastParticleTick;

  List<Particle> get activeParticles => _particles;

  Offset _from = Offset.zero;
  Offset _to = Offset.zero;

  /// The active piece's current interpolated (col, row) position.
  Offset get piecePos => Offset.lerp(_from, _to, move.value)!;

  /// Retargets the movement tween toward [to], rebasing from wherever the
  /// piece is *currently* interpolated to so rapid inputs never pop.
  void retargetPiece(
    Offset to, {
    required Duration duration,
    required Curve curve,
  }) {
    _from = piecePos;
    _to = to;
    move.value = 0;
    move.animateTo(1, duration: duration, curve: curve);
  }

  /// Places the piece instantly with no tween — used on spawn so a new
  /// piece never slides in from the previous piece's last position.
  void snapPiece(Offset pos) {
    _from = pos;
    _to = pos;
    move.value = 1;
  }

  /// A small decaying wobble for the hard-drop impact shake, scaled by the
  /// severity passed to the most recent [triggerShake].
  Offset get shakeOffset {
    final t = shake.value;
    final envelope = (1 - t) * (1 - t);
    final wobble = sin(t * pi * 6);
    return Offset(
      wobble * 6 * envelope * _shakeIntensity,
      wobble * 2.4 * envelope * _shakeIntensity,
    );
  }

  /// Triggers the hard-drop/big-clear screen shake, unless reduced motion
  /// is on. [intensity] scales the wobble amplitude (clamped 0.4-1.6) so a
  /// Tetris or a long hard drop reads as more forceful than a bare-minimum
  /// trigger of the same event.
  void triggerShake({double intensity = 1.0}) {
    if (reduceMotion) return;
    _shakeIntensity = intensity.clamp(0.4, 1.6);
    shake.forward(from: 0);
  }

  /// Triggers the hard-drop impact ring at [originGridPos] (grid units,
  /// same space as [piecePos]), unless reduced motion is on.
  void triggerImpactRing(Offset originGridPos) {
    if (reduceMotion) return;
    impactRingOrigin = originGridPos;
    impactRing.forward(from: 0);
  }

  /// Sets the current combo "heat" (0 = no combo, 1 = maximum). Starts the
  /// glow pulse on the rising edge and stops it once the combo drops back to
  /// zero — mirrors [setDanger]'s idempotent, edge-triggered shape.
  void setComboHeat(double heat) {
    comboHeat = heat.clamp(0.0, 1.0);
    if (comboHeat <= 0) {
      comboPulse.stop();
      comboPulse.value = 0;
      return;
    }
    if (!comboPulse.isAnimating) {
      comboPulse.repeat(reverse: true);
    }
  }

  /// Triggers the level-up flash, unless reduced motion is on.
  void triggerLevelUp() {
    if (reduceMotion) return;
    levelUp.forward(from: 0);
  }

  /// Triggers the new-personal-best celebration flash, unless reduced motion
  /// is on. The accompanying particle shower is the caller's responsibility
  /// (via [burst]) since it needs per-column origins the board painter owns.
  void triggerCelebration() {
    if (reduceMotion) return;
    celebration.forward(from: 0);
  }

  /// Starts or stops the danger-zone pulse. Idempotent — safe to call every
  /// frame with the same value.
  void setDanger(bool value) {
    if (value == _inDanger) return;
    _inDanger = value;
    if (value) {
      danger.repeat(reverse: true);
    } else {
      danger.stop();
      danger.value = 0;
    }
  }

  /// Stops and zeroes every transient visual — called at the start of a
  /// fresh run. Without this, a fast "Play Again" right after a new-best
  /// celebration (or mid-level-up-flash) could carry a still-animating
  /// [celebration]/[levelUp] controller straight into the new run's first
  /// frames, since their triggers are one-shot fire-and-forget with no
  /// natural cancellation point of their own.
  void resetForNewRun() {
    setDanger(false);
    setComboHeat(0);
    celebration.stop();
    celebration.value = 0;
    levelUp.stop();
    levelUp.value = 0;
    shake.stop();
    shake.value = 0;
    impactRing.stop();
    impactRing.value = 0;
    impactRingOrigin = null;
    lockFlash.stop();
    lockFlash.value = 0;
    lineClear.stop();
    lineClear.value = 0;
    particles.stop();
    _particles.clear();
  }

  /// Spawns a small burst of particles at [originGridPos] (grid units, same
  /// space as [piecePos]) in [color], and keeps the shared physics ticker
  /// running only while particles are actually alive.
  void burst(Offset originGridPos, Color color, {int count = 12}) {
    if (reduceMotion) count = (count / 3).ceil().clamp(1, count);
    for (int i = 0; i < count; i++) {
      final angle = _rand.nextDouble() * pi * 2;
      final speed = 2 + _rand.nextDouble() * 3;
      _particles.add(
        Particle(
          position: originGridPos,
          velocity: Offset(cos(angle), sin(angle) * 0.6 - 1.4) * speed,
          color: color,
          life: 0.45 + _rand.nextDouble() * 0.35,
        ),
      );
    }
    if (!particles.isAnimating) {
      _lastParticleTick = DateTime.now();
      particles.repeat();
    }
  }

  void _advanceParticles() {
    final now = DateTime.now();
    final dt = _lastParticleTick == null
        ? 0.0
        : (now.difference(_lastParticleTick!).inMicroseconds / 1e6).clamp(
            0.0,
            0.05,
          );
    _lastParticleTick = now;
    for (final p in _particles) {
      p.advance(dt);
    }
    _particles.removeWhere((p) => p.isDead);
    if (_particles.isEmpty) {
      particles.stop();
    }
  }

  /// Drives [CustomPainter] repaints directly, without rebuilding the
  /// surrounding widget tree.
  Listenable get repaint => Listenable.merge([
    move,
    lockFlash,
    lineClear,
    particles,
    danger,
    impactRing,
    comboPulse,
    levelUp,
    celebration,
  ]);

  void dispose() {
    move.dispose();
    lockFlash.dispose();
    lineClear.dispose();
    shake.dispose();
    particles.dispose();
    danger.dispose();
    impactRing.dispose();
    comboPulse.dispose();
    levelUp.dispose();
    celebration.dispose();
  }
}
