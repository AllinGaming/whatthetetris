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
      ) {
    // Used purely as a per-frame driver — its own 0..1 value is never read.
    particles.addListener(_advanceParticles);
  }

  final AnimationController move;
  final AnimationController lockFlash;
  final AnimationController lineClear;
  final AnimationController shake;
  final AnimationController particles;

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

  /// A small decaying wobble for the hard-drop impact shake.
  Offset get shakeOffset {
    final t = shake.value;
    final envelope = (1 - t) * (1 - t);
    final wobble = sin(t * pi * 6);
    return Offset(wobble * 6 * envelope, wobble * 2.4 * envelope);
  }

  /// Spawns a small burst of particles at [originGridPos] (grid units, same
  /// space as [piecePos]) in [color], and keeps the shared physics ticker
  /// running only while particles are actually alive.
  void burst(Offset originGridPos, Color color, {int count = 12}) {
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
  Listenable get repaint =>
      Listenable.merge([move, lockFlash, lineClear, particles]);

  void dispose() {
    move.dispose();
    lockFlash.dispose();
    lineClear.dispose();
    shake.dispose();
    particles.dispose();
  }
}
