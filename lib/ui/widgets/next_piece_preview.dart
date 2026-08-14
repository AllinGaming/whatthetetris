import 'package:flutter/material.dart';

import '../../game/tri_paint.dart';
import '../../models/piece.dart';

class NextPiecePreview extends StatelessWidget {
  const NextPiecePreview({
    super.key,
    required this.piece,
    required this.colorMode,
    this.size = 64,
    this.semanticLabel = 'Next piece',
    this.colorOverride,
  });

  final PieceDefinition piece;
  final PieceColorMode colorMode;
  final double size;
  final String semanticLabel;

  /// The active theme's color for this piece (docs/GDD.md SS6.5). Falls
  /// back to the piece catalog's default color when omitted. Only used as
  /// the resolved color under [PieceColorMode.colored] — see
  /// [resolveCellColor].
  final Color? colorOverride;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$semanticLabel: ${piece.name}',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: CustomPaint(
            painter: _NextPiecePainter(
              piece,
              colorOverride ?? piece.color,
              colorMode,
            ),
          ),
        ),
      ),
    );
  }
}

class _NextPiecePainter extends CustomPainter {
  _NextPiecePainter(this.piece, this.color, this.colorMode);

  final PieceDefinition piece;
  final Color color;
  final PieceColorMode colorMode;

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
      final cellColor = resolveCellColor(
        mode: colorMode,
        themedColor: color,
        kind: c.kind,
        tri: c.tri,
      );
      if (c.kind == CellKind.full) {
        paintFullCell(canvas, rect, cellColor);
      } else {
        paintTriHalf(canvas, rect, c.tri!, cellColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NextPiecePainter oldDelegate) =>
      oldDelegate.piece != piece ||
      oldDelegate.color != color ||
      oldDelegate.colorMode != colorMode;
}
