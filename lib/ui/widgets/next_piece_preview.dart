import 'package:flutter/material.dart';

import '../../game/tri_paint.dart';
import '../../models/piece.dart';

class NextPiecePreview extends StatelessWidget {
  const NextPiecePreview({super.key, required this.piece});

  final PieceDefinition piece;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: CustomPaint(painter: _NextPiecePainter(piece)),
    );
  }
}

class _NextPiecePainter extends CustomPainter {
  _NextPiecePainter(this.piece);

  final PieceDefinition piece;

  @override
  void paint(Canvas canvas, Size size) {
    final cells = piece.rotations.first;
    final maxRow = cells.map((c) => c.row).reduce((a, b) => a > b ? a : b);
    final maxCol = cells.map((c) => c.col).reduce((a, b) => a > b ? a : b);
    final gridSize = (maxRow > maxCol ? maxRow : maxCol) + 1;
    final cell = size.shortestSide / gridSize;
    final offsetX = (size.width - (maxCol + 1) * cell) / 2;
    final offsetY = (size.height - (maxRow + 1) * cell) / 2;

    for (final c in cells) {
      final rect = Rect.fromLTWH(
        offsetX + c.col * cell + 1,
        offsetY + c.row * cell + 1,
        cell - 2,
        cell - 2,
      );
      if (c.kind == CellKind.full) {
        paintFullCell(canvas, rect, piece.color);
      } else {
        paintTriHalf(canvas, rect, c.tri!, piece.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NextPiecePainter oldDelegate) =>
      oldDelegate.piece != piece;
}
