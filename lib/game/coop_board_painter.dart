import 'package:flutter/material.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/theme_palette.dart';
import 'coop_game_engine.dart';
import 'tri_paint.dart';

class CoopBoardPainter extends CustomPainter {
  const CoopBoardPainter({
    required this.board,
    required this.config,
    required this.redPiece,
    required this.bluePiece,
    required this.localGhost,
    required this.localPlayer,
    required this.revision,
    required this.theme,
  });

  final List<List<CellOccupancy>> board;
  final Config config;
  final ActivePiece? redPiece;
  final ActivePiece? bluePiece;
  final ActivePiece? localGhost;
  final CoopPlayer localPlayer;
  final int revision;
  final ThemePalette theme;

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

    canvas.drawRect(
      Rect.fromLTWH(0, startY, config.cols * cellSize, config.rows * cellSize),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white24,
    );
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
      paintTriHalf(canvas, rect, TriHalf.bl, duoBlColor);
    }
    if (occupancy.tr != null) {
      paintTriHalf(canvas, rect, TriHalf.tr, duoTrColor);
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
      oldDelegate.theme != theme;
}
