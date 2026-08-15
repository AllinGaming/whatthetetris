import 'dart:math';

import 'package:flutter/material.dart';

/// Two diagonals per square.
enum TriHalf { bl, tr }

extension TriHalfRotation on TriHalf {
  TriHalf rotateCW() => this == TriHalf.bl ? TriHalf.tr : TriHalf.bl;
}

enum CellKind { full, tri }

/// How locked/falling piece cells are colored (docs/GDD.md SS6.5). [duo] is
/// the recommended default: color signals triangle orientation only (see
/// [resolveCellColor]) rather than piece identity, so a player can tell at a
/// glance which half a cell still needs. [random] goes the opposite way:
/// each piece gets a fresh, shape-independent color on spawn, so color
/// carries *no* information at all, forcing the player to read shape alone
/// — noticeably harder to play, which is why picking it prompts a confirm.
enum PieceColorMode {
  duo,
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
/// what the cell renders as in [PieceColorMode.random] (its per-instance
/// random color -- the caller resolves it before calling this), or whatever
/// fixed/override color a caller wants rendered uniformly regardless of
/// [mode]; ignored entirely in [PieceColorMode.duo], where color is derived
/// purely from [kind]/[tri] instead.
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

  /// Purely a coordinate transform -- [PieceCell.tri] is carried through
  /// unchanged. A piece's triangle orientation ("uniform diagonal", docs/
  /// GDD.md SS3) is otherwise stable across rotation; only the explicit
  /// Mirror action (see [ActivePiece.cellsOnBoard]) is meant to flip it, so
  /// a player always knows why a half just changed color.
  static PieceCell _rotateCW(PieceCell cell) {
    final newRow = cell.col;
    final newCol = -cell.row;
    return PieceCell(row: newRow, col: newCol, kind: cell.kind, tri: cell.tri);
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
