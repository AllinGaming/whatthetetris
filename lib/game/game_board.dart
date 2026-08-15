import 'dart:math';

import 'package:flutter/material.dart';

import '../models/active_piece.dart';
import '../models/board.dart';
import '../models/piece.dart';

/// Mutable board rules isolated from Flutter widgets, timers, and animation.
///
/// The session controller owns when commands may run; this class owns only
/// deterministic placement and row mutation rules.
class GameBoard {
  GameBoard(this.config)
    : cells = List.generate(
        config.rows,
        (_) => List.generate(config.cols, (_) => CellOccupancy()),
      );

  final Config config;
  List<List<CellOccupancy>> cells;
  int revision = 0;

  bool canPlace(ActivePiece piece) {
    for (final cell in piece.cellsOnBoard()) {
      if (cell.row < 0 || cell.row >= config.rows) return false;
      if (cell.col < 0 || cell.col >= config.cols) return false;

      final target = cells[cell.row][cell.col];
      if (target.full != null) return false;
      if (cell.kind == CellKind.full) {
        if (target.bl != null || target.tr != null) return false;
      } else if (cell.tri == TriHalf.bl && target.bl != null) {
        return false;
      } else if (cell.tri == TriHalf.tr && target.tr != null) {
        return false;
      }
    }
    return true;
  }

  /// Counts cells this piece would complete by fusing a triangle half onto
  /// one *already on the board*, as opposed to landing on an empty cell.
  /// Must be called before [lock] mutates the board. This is the basis for
  /// the Fusion Bonus (docs/GDD.md SS4.1) — the scoring layer built from this
  /// game's own mechanic rather than an imported T-spin equivalent.
  int countFusions(ActivePiece piece) {
    int fusions = 0;
    for (final cell in piece.cellsOnBoard()) {
      if (cell.row < 0 || cell.row >= config.rows) continue;
      if (cell.col < 0 || cell.col >= config.cols) continue;
      if (cell.kind != CellKind.tri) continue;
      final target = cells[cell.row][cell.col];
      if (cell.tri == TriHalf.bl && target.tr != null) fusions++;
      if (cell.tri == TriHalf.tr && target.bl != null) fusions++;
    }
    return fusions;
  }

  /// [colorForCell] resolves each locked cell's stored color (docs/GDD.md
  /// SS6.5) — it's a per-cell callback rather than one fixed color because
  /// [PieceColorMode.duo] colors each cell by its own kind/orientation, not
  /// by piece identity, and a single piece can mix full and triangle cells.
  void lock(
    ActivePiece piece, {
    required Color Function(PieceCell) colorForCell,
  }) {
    for (final cell in piece.cellsOnBoard()) {
      final target = cells[cell.row][cell.col];
      final color = colorForCell(cell);
      if (cell.kind == CellKind.full) {
        target
          ..full = color
          ..bl = null
          ..tr = null;
      } else if (cell.tri == TriHalf.bl) {
        target.bl = color;
      } else {
        target.tr = color;
      }
    }
    revision++;
  }

  /// [colorForFill] resolves the color for the half being newly filled,
  /// given its orientation and the color already on the other half — under
  /// [PieceColorMode.random] that's just the existing color passed through,
  /// but under [PieceColorMode.duo] it must return the fixed color for that
  /// orientation instead of copying (copying would put bl's red into a tr
  /// slot, which should always read as blue).
  bool fillLowestCavity({
    required Color Function(TriHalf fillTri, Color existing) colorForFill,
  }) {
    for (int row = config.rows - 1; row >= 0; row--) {
      for (int col = 0; col < config.cols; col++) {
        final cell = cells[row][col];
        if (cell.full != null) continue;
        final hasBl = cell.bl != null;
        final hasTr = cell.tr != null;
        if (hasBl == hasTr) continue;
        final existing = hasBl ? cell.bl! : cell.tr!;
        final fillTri = hasBl ? TriHalf.tr : TriHalf.bl;
        final color = colorForFill(fillTri, existing);
        if (hasBl) {
          cell.tr = color;
        } else {
          cell.bl = color;
        }
        revision++;
        return true;
      }
    }
    return false;
  }

  List<int> detectFullRows() => [
    for (int row = 0; row < config.rows; row++)
      if (cells[row].every((cell) => cell.isFullyFilled)) row,
  ];

  /// True once every cell is empty — the win condition for
  /// [EndCondition.boardCleared] puzzle modes.
  bool get isEmpty => cells.every(
    (row) => row.every(
      (cell) => cell.full == null && cell.bl == null && cell.tr == null,
    ),
  );

  /// Deterministically fills roughly the bottom half of the board with a mix
  /// of full and single-triangle cells, for [GameModeConfig.startsPrefilled]
  /// puzzle modes — [random] should be seeded identically for every player
  /// on the same day. Retries a row if it would land 100% full: a
  /// pre-solved row would just sit there blocking pieces above it, since
  /// nothing re-checks for full rows outside of an actual piece lock.
  void seedPuzzle(
    Random random,
    Color Function(CellKind kind, TriHalf? tri) colorForCell,
  ) {
    const fillChance = 0.55;
    final startRow = config.rows ~/ 2;
    for (int row = startRow; row < config.rows; row++) {
      List<bool> fills;
      do {
        fills = [
          for (int c = 0; c < config.cols; c++)
            random.nextDouble() < fillChance,
        ];
      } while (fills.every((f) => f));
      for (int col = 0; col < config.cols; col++) {
        if (!fills[col]) continue;
        final cell = cells[row][col];
        if (random.nextBool()) {
          cell.full = colorForCell(CellKind.full, null);
        } else if (random.nextBool()) {
          cell.bl = colorForCell(CellKind.tri, TriHalf.bl);
        } else {
          cell.tr = colorForCell(CellKind.tri, TriHalf.tr);
        }
      }
    }
    revision++;
  }

  /// True once the stack has crept into the top [rows] rows — the danger
  /// zone warning (docs/GDD.md SS7) fires off this, independent of soft
  /// floor/top-out rules.
  bool isNearTop({int rows = 4}) {
    final count = rows.clamp(0, config.rows);
    for (int r = 0; r < count; r++) {
      for (final cell in cells[r]) {
        if (cell.full != null || cell.bl != null || cell.tr != null) {
          return true;
        }
      }
    }
    return false;
  }

  /// Wipes the top [n] rows in place (no shifting) rather than ending the
  /// run. Used by Chill/Zen's "soft floor" (docs/GDD.md SS5): a spawn that
  /// would otherwise top out instead costs the player some stacked height.
  void clearTopRows(int n) {
    final count = n.clamp(0, config.rows);
    for (int row = 0; row < count; row++) {
      cells[row] = List.generate(config.cols, (_) => CellOccupancy());
    }
    revision++;
  }

  void collapseRows(Iterable<int> rows) {
    final rowSet = rows.toSet();
    if (rowSet.isEmpty) return;
    final remaining = [
      for (int row = 0; row < config.rows; row++)
        if (!rowSet.contains(row)) cells[row],
    ];
    cells = [
      ...List.generate(
        rowSet.length,
        (_) => List.generate(config.cols, (_) => CellOccupancy()),
      ),
      ...remaining,
    ];
    revision++;
  }
}
