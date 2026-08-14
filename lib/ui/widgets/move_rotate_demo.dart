import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/tri_paint.dart';
import '../../models/piece.dart';
import '../../models/pieces.dart';

/// An interactive mini board for the tutorial: a real T4 piece the player
/// actually moves and rotates themselves with three small buttons, rather
/// than reading about what the arrows/rotate keys do. No gravity, no
/// locking — just enough of the real piece/rotation model
/// ([PieceDefinition.rotations]) to make the controls tangible.
class MoveRotateDemo extends StatefulWidget {
  const MoveRotateDemo({super.key, this.color, this.size = 132});

  final Color? color;
  final double size;

  @override
  State<MoveRotateDemo> createState() => _MoveRotateDemoState();
}

class _MoveRotateDemoState extends State<MoveRotateDemo> {
  static const _cols = 5;
  static const _rows = 3;

  late final _piece = Pieces.all.firstWhere((p) => p.name == 'T4');
  int _rotation = 0;
  int _col = 1;

  int _widthOf(List<PieceCell> cells) =>
      cells.map((c) => c.col).reduce(max) + 1;

  List<PieceCell> get _cells => _piece.rotations[_rotation];

  void _moveLeft() {
    setState(() => _col = (_col - 1).clamp(0, _cols - _widthOf(_cells)));
  }

  void _moveRight() {
    setState(() => _col = (_col + 1).clamp(0, _cols - _widthOf(_cells)));
  }

  void _rotate() {
    setState(() {
      final next = (_rotation + 1) % _piece.rotations.length;
      final nextWidth = _widthOf(_piece.rotations[next]);
      _rotation = next;
      _col = _col.clamp(0, _cols - nextWidth);
    });
  }

  Widget _miniButton(IconData icon, VoidCallback onPressed, Color accent) {
    return IconButton.filled(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.16),
        foregroundColor: accent,
        minimumSize: const Size(40, 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? Theme.of(context).colorScheme.primary;
    final cellSize = widget.size / _cols;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: cellSize * _cols,
            height: cellSize * _rows,
            child: CustomPaint(
              painter: _MoveRotatePainter(
                cells: _cells,
                col: _col,
                cellSize: cellSize,
                cols: _cols,
                rows: _rows,
                color: accent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _miniButton(Icons.chevron_left, _moveLeft, accent),
            const SizedBox(width: 10),
            _miniButton(Icons.rotate_right, _rotate, accent),
            const SizedBox(width: 10),
            _miniButton(Icons.chevron_right, _moveRight, accent),
          ],
        ),
      ],
    );
  }
}

class _MoveRotatePainter extends CustomPainter {
  _MoveRotatePainter({
    required this.cells,
    required this.col,
    required this.cellSize,
    required this.cols,
    required this.rows,
    required this.color,
  });

  final List<PieceCell> cells;
  final int col;
  final double cellSize;
  final int cols;
  final int rows;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int c = 0; c <= cols; c++) {
      final x = c * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int r = 0; r <= rows; r++) {
      final y = r * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final cell in cells) {
      final rect = Rect.fromLTWH(
        (col + cell.col) * cellSize + 1.5,
        cell.row * cellSize + 1.5,
        cellSize - 3,
        cellSize - 3,
      );
      if (cell.kind == CellKind.full) {
        paintFullCell(canvas, rect, color, glow: 0.15);
      } else {
        paintTriHalf(canvas, rect, cell.tri!, color, glow: 0.15);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MoveRotatePainter oldDelegate) =>
      oldDelegate.cells != cells ||
      oldDelegate.col != col ||
      oldDelegate.color != color;
}
