import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/tri_paint.dart';
import '../../models/piece.dart';
import 'app_route_observer.dart';

/// A small looping animation above the start screen title that acts out the
/// game's core, otherwise-unexplained hook — two opposite triangle halves
/// sliding together and fusing into a full cell — before the player has even
/// picked a mode.
class FusionHero extends StatefulWidget {
  const FusionHero({
    super.key,
    required this.colorA,
    required this.colorB,
    this.size = 96,
    this.reduceMotion = false,
  });

  final Color colorA;
  final Color colorB;
  final double size;

  /// The app's own Accessibility > "Reduce motion" toggle
  /// (`SettingsService.reduceMotion`) — distinct from, and checked in
  /// addition to, the OS-level `MediaQuery.disableAnimations` flag, since a
  /// player can turn one on without the other.
  final bool reduceMotion;

  @override
  State<FusionHero> createState() => _FusionHeroState();
}

class _FusionHeroState extends State<FusionHero>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _started = false;
  PageRoute<dynamic>? _subscribedRoute;

  bool get _skipMotion =>
      widget.reduceMotion || MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deferred to here (rather than initState) because it needs MediaQuery,
    // and guarded by _started since didChangeDependencies can re-fire.
    if (!_started) {
      _started = true;
      if (_skipMotion) {
        _controller.value = 0.7; // a static resting "fused" frame
      } else {
        _controller.repeat();
      }
    }
    // Pause/resume with its route so it doesn't keep ticking (and burning
    // CPU/battery) once buried under a pushed game/settings screen.
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => _controller.stop();

  @override
  void didPopNext() {
    if (!_skipMotion) _controller.repeat();
  }

  @override
  void dispose() {
    if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _FusionHeroPainter(
              t: _controller.value,
              colorA: widget.colorA,
              colorB: widget.colorB,
            ),
          ),
        ),
      ),
    );
    return visual;
  }
}

class _FusionHeroPainter extends CustomPainter {
  _FusionHeroPainter({
    required this.t,
    required this.colorA,
    required this.colorB,
  });

  final double t;
  final Color colorA;
  final Color colorB;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.shortestSide * 0.42;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: cell, height: cell);

    final appear = (t / 0.15).clamp(0.0, 1.0);
    final slide = Curves.easeOutCubic.transform(
      ((t - 0.15) / 0.30).clamp(0.0, 1.0),
    );
    final fuse = ((t - 0.45) / 0.17).clamp(0.0, 1.0);
    final fadeOut = t > 0.82 ? 1 - ((t - 0.82) / 0.18).clamp(0.0, 1.0) : 1.0;
    if (fadeOut <= 0) return;

    if (t < 0.45) {
      paintTriHalf(canvas, rect, TriHalf.bl, colorA, opacity: appear * fadeOut);
      if (slide > 0) {
        final travel = cell * 0.9 * (1 - slide);
        paintTriHalf(
          canvas,
          rect.shift(Offset(travel, -travel)),
          TriHalf.tr,
          colorB,
          opacity: slide * fadeOut,
        );
      }
    } else {
      final blended = Color.lerp(colorA, colorB, 0.5)!;
      final flash = 1 - fuse;
      final scale = 1 + 0.15 * sin(fuse * pi);
      // A floor on top of the flash decay — visually confirmed via golden
      // snapshot that `glow: flash` alone settles at a flat, washed-out grey
      // once the flash fully decays (fuse >= 1), since a naive RGB lerp of
      // two saturated colors desaturates. The real board never lets the
      // active piece go fully flat either (a permanent `glow: 0.15`); this
      // matches that floor, and matters here since reduce-motion users see
      // this settled frame indefinitely, not just mid-loop.
      final glow = 0.4 + flash * 0.6;
      paintFullCell(
        canvas,
        Rect.fromCenter(
          center: center,
          width: cell * scale,
          height: cell * scale,
        ),
        blended,
        glow: glow,
        opacity: fadeOut,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FusionHeroPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.colorA != colorA ||
      oldDelegate.colorB != colorB;
}
