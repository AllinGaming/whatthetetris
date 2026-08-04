import 'dart:math';

import 'package:flutter/material.dart';

/// Two diagonals per square.
enum TriHalf { bl, tr }

extension TriHalfRotation on TriHalf {
  TriHalf rotateCW() => this == TriHalf.bl ? TriHalf.tr : TriHalf.bl;
}

enum CellKind { full, tri }

class PieceCell {
  const PieceCell({
    required this.row,
    required this.col,
    required this.kind,
    this.tri,
  });

  final int row;
  final int col;
  final CellKind kind;
  final TriHalf? tri;
}

class PieceDefinition {
  PieceDefinition({
    required this.name,
    required List<PieceCell> base,
    required this.color,
  }) : rotations = _buildRotations(base);

  final String name;
  final List<List<PieceCell>> rotations;
  final Color color;

  static List<List<PieceCell>> _buildRotations(List<PieceCell> base) {
    final rotations = <List<PieceCell>>[];
    List<PieceCell> current = base;
    for (int i = 0; i < 4; i++) {
      rotations.add(_normalize(current));
      current = current.map(_rotateCW).toList();
    }
    return rotations;
  }

  static PieceCell _rotateCW(PieceCell cell) {
    final newRow = cell.col;
    final newCol = -cell.row;
    return PieceCell(
      row: newRow,
      col: newCol,
      kind: cell.kind,
      tri: cell.tri?.rotateCW(),
    );
  }

  static List<PieceCell> _normalize(List<PieceCell> cells) {
    final minR = cells.map((c) => c.row).reduce(min);
    final minC = cells.map((c) => c.col).reduce(min);
    return cells
        .map(
          (c) => PieceCell(
            row: c.row - minR,
            col: c.col - minC,
            kind: c.kind,
            tri: c.tri,
          ),
        )
        .toList();
  }
}
