import 'package:flutter/material.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/theme_palette.dart';
import 'coop_game_engine.dart';
import 'game_animations.dart';
import 'tri_paint.dart';

class CoopBoardPainter extends CustomPainter {
  CoopBoardPainter({
    required this.board,
    required this.config,
    required this.redPiece,
    required this.bluePiece,
    required this.localGhost,
    required this.localPlayer,
    required this.revision,
    required this.theme,
    required this.anim,
    required this.effectCells,
    required this.clearingRows,
  }) : super(repaint: anim.repaint);

  final List<List<CellOccupancy>> board;
  final Config config;
  final ActivePiece? redPiece;
  final ActivePiece? bluePiece;
  final ActivePiece? localGhost;
  final CoopPlayer localPlayer;
  final int revision;
  final ThemePalette theme;
  final GameAnimations anim;
  final List<int> effectCells;
  final List<int> clearingRows;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / config.cols;
    final startY = size.height - config.rows * cellSize;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.backgroundTop, theme.backgroundBottom],
        ).createShader(Offset.zero & size),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (int col = 1; col < config.cols; col++) {
      final x = col * cellSize;
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, startY + config.rows * cellSize),
        gridPaint,
      );
    }
    for (int row = 1; row < config.rows; row++) {
      final y = startY + row * cellSize;
      canvas.drawLine(
        Offset(0, y),
        Offset(config.cols * cellSize, y),
        gridPaint,
      );
    }

    for (int row = 0; row < config.rows; row++) {
      for (int col = 0; col < config.cols; col++) {
        _paintOccupancy(
          canvas,
          _rect(row, col, cellSize, startY),
          board[row][col],
        );
      }
    }

    if (effectCells.isNotEmpty && anim.lockFlash.isAnimating) {
      final glow = (1 - anim.lockFlash.value).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: glow * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      for (final index in effectCells) {
        final row = index ~/ config.cols;
        final col = index % config.cols;
        if (row >= 0 && row < config.rows) {
          canvas.drawRect(_rect(row, col, cellSize, startY), paint);
        }
      }
    }

    if (clearingRows.isNotEmpty && anim.lineClear.isAnimating) {
      final flash = _clearFlashEnvelope(anim.lineClear.value);
      for (final row in clearingRows) {
        if (row < 0 || row >= config.rows) continue;
        canvas.drawRect(
          Rect.fromLTWH(0, startY + row * cellSize, size.width, cellSize),
          Paint()..color = Colors.white.withValues(alpha: flash * 0.78),
        );
      }
    }
    final localActive = localPlayer == CoopPlayer.red ? redPiece : bluePiece;
    if (localGhost != null && localGhost!.row != localActive?.row) {
      _paintPiece(
        canvas,
        localGhost,
        localPlayer.color,
        cellSize,
        startY,
        opacity: 0.22,
      );
    }
    _paintPiece(canvas, redPiece, duoBlColor, cellSize, startY);
    _paintPiece(canvas, bluePiece, duoTrColor, cellSize, startY);

    if (anim.danger.value > 0) {
      final pulse = anim.danger.value;
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 + pulse * 4
          ..color = Colors.redAccent.withValues(alpha: 0.15 + pulse * 0.35),
      );
    }

    if (anim.comboHeat > 0) {
      final pulse = 0.5 + 0.5 * anim.comboPulse.value;
      canvas.drawRect(
        Rect.fromLTWH(0, startY, size.width, config.rows * cellSize),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Color.lerp(
            theme.accent,
            Colors.redAccent,
            anim.comboHeat,
          )!.withValues(alpha: (0.12 + 0.2 * pulse) * anim.comboHeat)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
      );
    }

    if (anim.levelUp.isAnimating) {
      final t = anim.levelUp.value;
      final envelope = t < 0.3 ? t / 0.3 : 1 - (t - 0.3) / 0.7;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = theme.accent.withValues(alpha: envelope * 0.22),
      );
    }

    if (anim.celebration.isAnimating) {
      final t = anim.celebration.value;
      final envelope = t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.amberAccent.withValues(alpha: envelope * 0.28),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, startY, config.cols * cellSize, config.rows * cellSize),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = const LinearGradient(colors: [duoBlColor, duoTrColor])
            .createShader(
              Rect.fromLTWH(
                0,
                startY,
                config.cols * cellSize,
                config.rows * cellSize,
              ),
            ),
    );

    // Impact effects are deliberately last. This keeps red/blue ownership and
    // hard-drop feedback legible over active pieces, line flashes, danger
    // pulses, and celebration washes on both peers.
    _paintParticlesAndImpact(canvas, size, cellSize, startY);
  }

  void _paintParticlesAndImpact(
    Canvas canvas,
    Size size,
    double cellSize,
    double startY,
  ) {
    final haloPaint = Paint()..blendMode = BlendMode.plus;
    final corePaint = Paint()..blendMode = BlendMode.plus;
    final sparkPaint = Paint()..blendMode = BlendMode.plus;
    for (final particle in anim.activeParticles) {
      final center = Offset(
        particle.position.dx * cellSize,
        startY + particle.position.dy * cellSize,
      );
      if (center.dx < -cellSize ||
          center.dx > size.width + cellSize ||
          center.dy < -cellSize ||
          center.dy > size.height + cellSize) {
        continue;
      }
      final opacity = particle.opacity;
      final radius = cellSize * (0.085 + opacity * 0.025);
      canvas.drawCircle(
        center,
        radius * 2.35,
        haloPaint..color = particle.color.withValues(alpha: opacity * 0.20),
      );
      canvas.drawCircle(
        center,
        radius,
        corePaint..color = particle.color.withValues(alpha: opacity * 0.92),
      );
      canvas.drawCircle(
        center,
        radius * 0.36,
        sparkPaint..color = Colors.white.withValues(alpha: opacity * 0.86),
      );
    }

    final ringOrigin = anim.impactRingOrigin;
    if (ringOrigin == null || !anim.impactRing.isAnimating) return;
    final t = anim.impactRing.value;
    final center = Offset(
      ringOrigin.dx * cellSize,
      startY + ringOrigin.dy * cellSize,
    );
    final fade = 1 - t;
    canvas.drawCircle(
      center,
      cellSize * (0.32 + t * 1.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade + 0.6
        ..color = anim.impactRingColor.withValues(alpha: fade * 0.80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      center,
      cellSize * (0.22 + t * 1.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: fade * 0.72),
    );
  }

  double _clearFlashEnvelope(double t) {
    if (t < 0.25) return t / 0.25;
    if (t < 0.5) return 1 - (t - 0.25) / 0.25 * 0.7;
    if (t < 0.75) return 0.3 + (t - 0.5) / 0.25 * 0.7;
    return 1 - (t - 0.75) / 0.25;
  }

  Rect _rect(int row, int col, double cellSize, double startY) => Rect.fromLTWH(
    col * cellSize + 1,
    startY + row * cellSize + 1,
    cellSize - 2,
    cellSize - 2,
  );

  void _paintOccupancy(Canvas canvas, Rect rect, CellOccupancy occupancy) {
    if (occupancy.full != null ||
        (occupancy.bl != null && occupancy.tr != null)) {
      paintFullCell(canvas, rect, duoFullColor);
      return;
    }
    if (occupancy.bl != null) {
      paintTriHalf(canvas, rect, TriHalf.bl, occupancy.bl!);
    }
    if (occupancy.tr != null) {
      paintTriHalf(canvas, rect, TriHalf.tr, occupancy.tr!);
    }
  }

  void _paintPiece(
    Canvas canvas,
    ActivePiece? piece,
    Color color,
    double cellSize,
    double startY, {
    double opacity = 1,
  }) {
    if (piece == null) return;
    for (final cell in piece.cellsOnBoard()) {
      if (cell.row < 0 ||
          cell.row >= config.rows ||
          cell.col < 0 ||
          cell.col >= config.cols) {
        continue;
      }
      final rect = _rect(cell.row, cell.col, cellSize, startY);
      if (cell.kind == CellKind.full) {
        paintFullCell(
          canvas,
          rect,
          color,
          glow: opacity == 1 ? 0.18 : 0,
          opacity: opacity,
        );
      } else {
        paintTriHalf(
          canvas,
          rect,
          cell.tri!,
          color,
          glow: opacity == 1 ? 0.18 : 0,
          opacity: opacity,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CoopBoardPainter oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.board != board ||
      oldDelegate.redPiece != redPiece ||
      oldDelegate.bluePiece != bluePiece ||
      oldDelegate.localGhost != localGhost ||
      oldDelegate.localPlayer != localPlayer ||
      oldDelegate.effectCells != effectCells ||
      oldDelegate.clearingRows != clearingRows ||
      oldDelegate.theme != theme;
}
