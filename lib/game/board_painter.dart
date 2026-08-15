import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/theme_palette.dart';
import 'game_animations.dart';
import 'tri_paint.dart';

/// Persists the recorded "static" half of the board (background/grid/locked
/// cells/border/pause overlay) across [BoardPainter] instances, which are
/// recreated on every rebuild. A [BoardPainter] repaints at 60fps for the
/// entire time any piece is falling (see [GameAnimations.move] retargeting
/// on every gravity tick in `GameScreen._tick`), but locked-cell content
/// itself only actually changes on a lock/clear/cavity-fill -- redrawing
/// all ~200 cells from scratch on every one of those frames was a real,
/// measurable cost (shader/Paint work per cell, every frame, for the whole
/// game). Owned by `GameScreen` as a single long-lived instance (unlike the
/// painter) so the cache survives across rebuilds.
class BoardStaticCache {
  ui.Picture? picture;
  Object? key;
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.board,
    required this.active,
    required this.ghost,
    required this.config,
    required this.boardRevision,
    required this.state,
    required this.lockedCells,
    required this.clearingRows,
    required this.anim,
    required this.theme,
    required this.colorMode,
    required this.activeThemeColor,
    required this.staticCache,
  }) : super(repaint: anim.repaint);

  final List<List<CellOccupancy>> board;
  final ActivePiece? active;
  final ActivePiece? ghost;
  final Config config;
  final int boardRevision;
  final GameState state;
  final List<PieceCell> lockedCells;
  final List<int> clearingRows;
  final GameAnimations anim;
  final ThemePalette theme;
  final PieceColorMode colorMode;
  final BoardStaticCache staticCache;

  /// The falling piece's already-resolved color — pre-resolved by the caller
  /// (rather than this painter calling `theme.colorFor(active.type.name)`
  /// itself) because [PieceColorMode.random] needs a per-instance color the
  /// painter has no way to know about. Unused when [active] is null. [ghost]
  /// always shares [active]'s type (it's the same piece's drop preview), so
  /// one color serves both.
  final Color activeThemeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / config.cols;
    final startY = size.height - config.rows * cell;

    _paintStatic(canvas, size, cell, startY);
    _paintDynamic(canvas, size, cell, startY);
  }

  /// Background, grid, locked cells (with their brief post-lock glow), and
  /// the clearing-row flash — recorded once into a cached [ui.Picture] and
  /// simply replayed on subsequent frames where none of that content
  /// actually changed, instead of reissuing ~200 cells' worth of paint
  /// calls every frame.
  void _paintStatic(Canvas canvas, Size size, double cell, double startY) {
    final lockFlashActive = anim.lockFlash.isAnimating;
    final lineClearActive = anim.lineClear.isAnimating;
    final key = (
      size,
      board,
      boardRevision,
      lockedCells,
      clearingRows,
      theme,
      colorMode,
      state,
      // -1 when idle so the key stays stable between animations (both read
      // as "not animating") rather than pinning to whatever value each
      // happened to end on.
      lockFlashActive ? anim.lockFlash.value : -1.0,
      lineClearActive ? anim.lineClear.value : -1.0,
    );

    if (staticCache.picture == null ||
        staticCache.key != key ||
        lockFlashActive ||
        lineClearActive) {
      final recorder = ui.PictureRecorder();
      _recordStatic(Canvas(recorder), size, cell, startY);
      staticCache.picture = recorder.endRecording();
      staticCache.key = key;
    }
    canvas.drawPicture(staticCache.picture!);
  }

  Rect _rectFor(double row, double col, double cell, double startY) {
    final x = col * cell;
    final y = startY + row * cell;
    return Rect.fromLTWH(x + 1, y + 1, cell - 2, cell - 2);
  }

  void _recordStatic(Canvas canvas, Size size, double cell, double startY) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [theme.backgroundTop, theme.backgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (int c = 1; c < config.cols; c++) {
      final x = c * cell;
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, startY + config.rows * cell),
        gridPaint,
      );
    }
    for (int r = 1; r < config.rows; r++) {
      final y = startY + r * cell;
      canvas.drawLine(Offset(0, y), Offset(config.cols * cell, y), gridPaint);
    }

    final lockGlow = (1 - anim.lockFlash.value).clamp(0.0, 1.0);
    final lockedKeys = <int>{
      for (final c in lockedCells) c.row * config.cols + c.col,
    };

    for (int r = 0; r < config.rows; r++) {
      for (int c = 0; c < config.cols; c++) {
        final cellData = board[r][c];
        final glow = lockedKeys.contains(r * config.cols + c) ? lockGlow : 0.0;
        final rect = _rectFor(r.toDouble(), c.toDouble(), cell, startY);
        if (cellData.full != null) {
          paintFullCell(canvas, rect, cellData.full!, glow: glow);
        } else if (cellData.bl != null && cellData.tr != null) {
          // Two triangle halves (from separate piece drops, possibly
          // different colors — see Fusion Bonus, docs/GDD.md SS4.1) fused
          // into a complete cell: gray it out rather than showing the two
          // original piece colors, so a filled cell reads as "done".
          paintFullCell(canvas, rect, duoFullColor, glow: glow);
        } else {
          if (cellData.bl != null) {
            paintTriHalf(canvas, rect, TriHalf.bl, cellData.bl!, glow: glow);
          }
          if (cellData.tr != null) {
            paintTriHalf(canvas, rect, TriHalf.tr, cellData.tr!, glow: glow);
          }
        }
      }
    }

    if (clearingRows.isNotEmpty) {
      final flash = _clearFlashEnvelope(anim.lineClear.value);
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75 * flash);
      for (final r in clearingRows) {
        canvas.drawRect(
          Rect.fromLTWH(0, startY + r * cell, config.cols * cell, cell),
          flashPaint,
        );
      }
    }
  }

  /// Everything that genuinely needs a fresh frame every time this repaints
  /// (the falling piece, ghost, particles, and every transient effect),
  /// drawn directly (not cached) on top of [_paintStatic]'s picture, in the
  /// same relative order as before the static/dynamic split so nothing's
  /// z-order changed -- in particular the pause/game-over dim still lands
  /// on top of the falling piece and effects, not underneath them.
  void _paintDynamic(Canvas canvas, Size size, double cell, double startY) {
    if (ghost != null && active != null && ghost!.row != active!.row) {
      for (final cellPos in ghost!.cellsOnBoard()) {
        final rect = _rectFor(
          cellPos.row.toDouble(),
          cellPos.col.toDouble(),
          cell,
          startY,
        );
        final ghostColor = resolveCellColor(
          mode: colorMode,
          themedColor: activeThemeColor,
          kind: cellPos.kind,
          tri: cellPos.tri,
        );
        if (cellPos.kind == CellKind.full) {
          paintFullCell(canvas, rect, ghostColor, opacity: 0.18);
        } else {
          paintTriHalf(canvas, rect, cellPos.tri!, ghostColor, opacity: 0.22);
        }
      }
    }

    if (active != null) {
      final basePos = Offset(active!.col.toDouble(), active!.row.toDouble());
      final animOffset = anim.piecePos - basePos;
      for (final cellPos in active!.cellsOnBoard()) {
        final rect = _rectFor(
          cellPos.row + animOffset.dy,
          cellPos.col + animOffset.dx,
          cell,
          startY,
        );
        final activeColor = resolveCellColor(
          mode: colorMode,
          themedColor: activeThemeColor,
          kind: cellPos.kind,
          tri: cellPos.tri,
        );
        if (cellPos.kind == CellKind.full) {
          paintFullCell(canvas, rect, activeColor, glow: 0.15);
        } else {
          paintTriHalf(canvas, rect, cellPos.tri!, activeColor, glow: 0.15);
        }
      }
    }

    // One reused Paint for the whole burst rather than one per particle —
    // a fast combo/tetris can have dozens alive at once, every frame.
    final particlePaint = Paint();
    for (final p in anim.activeParticles) {
      final px = p.position.dx * cell;
      final py = startY + p.position.dy * cell;
      canvas.drawCircle(
        Offset(px, py),
        cell * 0.09,
        particlePaint..color = p.color.withValues(alpha: p.opacity),
      );
    }

    final ringOrigin = anim.impactRingOrigin;
    if (ringOrigin != null && anim.impactRing.isAnimating) {
      final t = anim.impactRing.value;
      final ringCenter = Offset(
        ringOrigin.dx * cell,
        startY + ringOrigin.dy * cell,
      );
      canvas.drawCircle(
        ringCenter,
        cell * (0.3 + t * 1.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - t)
          ..color = Colors.white.withValues(alpha: (1 - t) * 0.6),
      );
    }

    if (anim.danger.value > 0 && state == GameState.playing) {
      final pulse = anim.danger.value;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 + pulse * 4
          ..color = Colors.redAccent.withValues(alpha: 0.15 + pulse * 0.35),
      );
    }

    // A soft blurred glow around the board while a combo streak is alive —
    // the combo counterpart to the crisp danger border above, confined to
    // the board rect and blurred so the two never read as the same signal.
    if (anim.comboHeat > 0 && state == GameState.playing) {
      final glowColor = Color.lerp(
        theme.accent,
        Colors.redAccent,
        anim.comboHeat,
      )!;
      final pulse = 0.5 + 0.5 * anim.comboPulse.value;
      canvas.drawRect(
        Rect.fromLTWH(0, startY, config.cols * cell, config.rows * cell),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = glowColor.withValues(
            alpha: (0.12 + 0.18 * pulse) * anim.comboHeat,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
      );
    }

    // A brief whole-board flash on level-up, layered on top of the existing
    // "LEVEL n!" toast/SFX rather than replacing it.
    if (anim.levelUp.isAnimating) {
      final t = anim.levelUp.value;
      final envelope = t < 0.3 ? t / 0.3 : 1 - (t - 0.3) / 0.7;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = theme.accent.withValues(alpha: envelope * 0.22),
      );
    }

    // A slower, warmer flash for a new personal best — plays alongside the
    // particle shower the game screen starts at the same moment.
    if (anim.celebration.isAnimating) {
      final t = anim.celebration.value;
      final envelope = t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.amberAccent.withValues(alpha: envelope * 0.28),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, startY, config.cols * cell, config.rows * cell),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white24
        ..strokeWidth = 1.5,
    );

    if (state == GameState.paused || state == GameState.over) {
      // Paused gets a dim backdrop for the PauseMenu widget overlay on top
      // of this canvas (its own title/buttons, not drawn here). Game Over
      // still gets its own label — ResultsScreen shows a moment later, but
      // there's a frame or two where only this canvas has painted.
      final overlay = Paint()
        ..color = Colors.black.withValues(
          alpha: state == GameState.over ? 0.55 : 0.35,
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlay);
      if (state == GameState.over) {
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'Game Over',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              shadows: [
                Shadow(color: Color(0xE6FF6E6E), blurRadius: 8),
                Shadow(color: Color(0x99FF6E6E), blurRadius: 20),
                Shadow(color: Colors.black, blurRadius: 4),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width);
        textPainter.paint(
          canvas,
          Offset(
            (size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2,
          ),
        );
      }
    }
  }

  /// A quick four-stop brighten/dim flicker over the line-clear animation.
  double _clearFlashEnvelope(double t) {
    if (t < 0.25) return t / 0.25;
    if (t < 0.5) return 1 - (t - 0.25) / 0.25 * 0.7;
    if (t < 0.75) return 0.3 + (t - 0.5) / 0.25 * 0.7;
    return 1 - (t - 0.75) / 0.25;
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.boardRevision != boardRevision ||
        oldDelegate.active != active ||
        oldDelegate.ghost != ghost ||
        oldDelegate.state != state ||
        oldDelegate.lockedCells != lockedCells ||
        oldDelegate.clearingRows != clearingRows ||
        oldDelegate.theme != theme ||
        oldDelegate.colorMode != colorMode ||
        oldDelegate.activeThemeColor != activeThemeColor;
  }
}
