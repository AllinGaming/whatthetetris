import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/tri_paint.dart';
import '../../models/piece.dart';
import '../../models/pieces.dart';
import '../../models/theme_palette.dart';
import 'app_route_observer.dart';

/// Full-bleed decorative background for menu-style screens (start screen,
/// and anywhere else that wants the same identity): the board's own
/// gradient + faint grid for visual continuity between menu and gameplay,
/// plus a handful of slow-drifting, very-low-opacity piece silhouettes for
/// atmosphere. Purely decorative — sits behind everything and never
/// intercepts input.
class MenuBackdrop extends StatefulWidget {
  const MenuBackdrop({
    super.key,
    required this.theme,
    this.reduceMotion = false,
  });

  final ThemePalette theme;

  /// The app's own Accessibility > "Reduce motion" toggle
  /// (`SettingsService.reduceMotion`) — distinct from, and checked in
  /// addition to, the OS-level `MediaQuery.disableAnimations` flag, since a
  /// player can turn one on without the other.
  final bool reduceMotion;

  @override
  State<MenuBackdrop> createState() => _MenuBackdropState();
}

class _MenuBackdropState extends State<MenuBackdrop>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );
  late final List<_DriftingPiece> _pieces = _buildPieces();
  bool _started = false;
  PageRoute<dynamic>? _subscribedRoute;

  bool get _skipMotion =>
      widget.reduceMotion || MediaQuery.of(context).disableAnimations;

  static List<_DriftingPiece> _buildPieces() {
    // Fixed seed: a stable, non-jittery layout across rebuilds, rather than
    // a new random scatter every time the screen redraws.
    final rand = Random(7);
    return List.generate(6, (_) {
      final piece = Pieces.all[rand.nextInt(Pieces.all.length)];
      return _DriftingPiece(
        piece: piece,
        x: rand.nextDouble(),
        phase: rand.nextDouble(),
        speed: 0.5 + rand.nextDouble() * 0.7,
        scale: 0.7 + rand.nextDouble() * 0.7,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (_skipMotion) {
        _controller.value = 0;
      } else {
        _controller.repeat();
      }
    }
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  // RouteAware — this backdrop lives on whichever screen embeds it, so it
  // must stop ticking the instant another route is pushed on top (it's
  // fully obscured but the Ticker keeps firing regardless of paint
  // occlusion) and only resume once that route is popped and this one is
  // visible again.
  @override
  void didPushNext() => _controller.stop();

  @override
  void didPopNext() {
    if (!_skipMotion) _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _MenuBackdropPainter(
                t: _controller.value,
                theme: widget.theme,
                pieces: _pieces,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriftingPiece {
  _DriftingPiece({
    required this.piece,
    required this.x,
    required this.phase,
    required this.speed,
    required this.scale,
  });

  final PieceDefinition piece;
  final double x; // horizontal position, 0..1 of the canvas width
  final double phase; // starting point within the fall loop, 0..1
  final double speed; // relative fall-speed multiplier
  final double scale;
}

class _MenuBackdropPainter extends CustomPainter {
  _MenuBackdropPainter({
    required this.t,
    required this.theme,
    required this.pieces,
  });

  final double t;
  final ThemePalette theme;
  final List<_DriftingPiece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [theme.backgroundTop, theme.backgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.028)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final p in pieces) {
      final loopT = (t * p.speed + p.phase) % 1.0;
      final cellSize = 22.0 * p.scale;
      final maxRow = p.piece.rotations.first
          .map((c) => c.row)
          .reduce((a, b) => a > b ? a : b);
      final pieceHeight = (maxRow + 1) * cellSize;
      final travel = size.height + pieceHeight * 2;
      final y = -pieceHeight + loopT * travel;
      final color = theme.colorFor(p.piece.name);

      canvas.save();
      canvas.translate(p.x * size.width, y);
      for (final cell in p.piece.rotations.first) {
        final rect = Rect.fromLTWH(
          cell.col * cellSize,
          cell.row * cellSize,
          cellSize - 2,
          cellSize - 2,
        );
        if (cell.kind == CellKind.full) {
          paintFullCell(canvas, rect, color, opacity: 0.07);
        } else {
          paintTriHalf(canvas, rect, cell.tri!, color, opacity: 0.07);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MenuBackdropPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.theme != theme;
}
