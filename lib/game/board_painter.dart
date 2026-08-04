import 'package:flutter/material.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/piece.dart';
import 'game_animations.dart';
import 'tri_paint.dart';

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.board,
    required this.active,
    required this.config,
    required this.state,
    required this.lockedCells,
    required this.clearingRows,
    required this.anim,
  }) : super(repaint: anim.repaint);

  final List<List<CellOccupancy>> board;
  final ActivePiece? active;
  final Config config;
  final GameState state;
  final List<PieceCell> lockedCells;
  final List<int> clearingRows;
  final GameAnimations anim;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / config.cols;
    final startY = size.height - config.rows * cell;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0F131D), Color(0xFF0B0E14)],
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

    Rect rectFor(double row, double col) {
      final x = col * cell;
      final y = startY + row * cell;
      return Rect.fromLTWH(x + 1, y + 1, cell - 2, cell - 2);
    }

    final lockGlow = (1 - anim.lockFlash.value).clamp(0.0, 1.0);
    final lockedKeys = <int>{
      for (final c in lockedCells) c.row * config.cols + c.col,
    };

    for (int r = 0; r < config.rows; r++) {
      for (int c = 0; c < config.cols; c++) {
        final cellData = board[r][c];
        final glow = lockedKeys.contains(r * config.cols + c) ? lockGlow : 0.0;
        final rect = rectFor(r.toDouble(), c.toDouble());
        if (cellData.full != null) {
          paintFullCell(canvas, rect, cellData.full!, glow: glow);
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

    if (active != null) {
      final basePos = Offset(active!.col.toDouble(), active!.row.toDouble());
      final animOffset = anim.piecePos - basePos;
      for (final cellPos in active!.cellsOnBoard()) {
        final rect = rectFor(
          cellPos.row + animOffset.dy,
          cellPos.col + animOffset.dx,
        );
        if (cellPos.kind == CellKind.full) {
          paintFullCell(canvas, rect, active!.type.color, glow: 0.15);
        } else {
          paintTriHalf(canvas, rect, cellPos.tri!, active!.type.color, glow: 0.15);
        }
      }
    }

    for (final p in anim.activeParticles) {
      final px = p.position.dx * cell;
      final py = startY + p.position.dy * cell;
      canvas.drawCircle(
        Offset(px, py),
        cell * 0.09,
        Paint()..color = p.color.withValues(alpha: p.opacity),
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
      final overlay = Paint()
        ..color = Colors.black.withValues(
          alpha: state == GameState.over ? 0.55 : 0.35,
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlay);
      final glowColor = state == GameState.over
          ? const Color(0xFFFF6E6E)
          : const Color(0xFF66E0F4);
      final textPainter = TextPainter(
        text: TextSpan(
          text: state == GameState.over ? 'Game Over' : 'Paused',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            shadows: [
              Shadow(color: glowColor.withValues(alpha: 0.9), blurRadius: 8),
              Shadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 20),
              const Shadow(color: Colors.black, blurRadius: 4),
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
        oldDelegate.active != active ||
        oldDelegate.state != state ||
        oldDelegate.lockedCells != lockedCells ||
        oldDelegate.clearingRows != clearingRows;
  }
}
