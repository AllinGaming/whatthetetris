import 'dart:math';

import 'package:flutter/material.dart';

/// Two diagonals per square.
enum TriHalf { bl, tr }

extension TriHalfRotation on TriHalf {
  TriHalf rotateCW() => this == TriHalf.bl ? TriHalf.tr : TriHalf.bl;
}

enum CellKind { full, tri }

/// How locked/falling piece cells are colored (docs/GDD.md SS6.5). [duo] is
/// the default, easier mode: color signals triangle orientation only (see
/// [resolveCellColor]) rather than piece identity, so a player can tell at a
/// glance which half a cell still needs, regardless of which piece dropped
/// it. [colored] restores the classic per-piece-type theme palette, which
/// hides that signal behind seven colors and is harder to read at speed.
/// [random] goes further: each piece gets a fresh, shape-independent color
/// on spawn, so color carries *no* information at all — not even the
/// learnable "this shape is always this color" of [colored] — forcing the
/// player to read shape alone.
enum PieceColorMode {
  duo,
  colored,
  random;

  static PieceColorMode fromName(String? name) => values.firstWhere(
    (v) => v.name == name,
    orElse: () => PieceColorMode.duo,
  );
}

const duoBlColor = Color(0xFFFF5C5C);
const duoTrColor = Color(0xFF5C9CFF);
const duoFullColor = Color(0xFF9E9E9E);

/// Resolves the paint color for a single cell under [mode]. [themedColor] is
/// what the cell renders as in [PieceColorMode.colored]/[PieceColorMode.random]
/// (the piece's theme color, or its per-instance random color respectively —
/// the caller resolves which one applies before calling this); ignored
/// entirely in [PieceColorMode.duo], where color is derived purely from
/// [kind]/[tri] instead.
Color resolveCellColor({
  required PieceColorMode mode,
  required Color themedColor,
  required CellKind kind,
  TriHalf? tri,
}) {
  if (mode != PieceColorMode.duo) return themedColor;
  if (kind == CellKind.full) return duoFullColor;
  return tri == TriHalf.tr ? duoTrColor : duoBlColor;
}

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
