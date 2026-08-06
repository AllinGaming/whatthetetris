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

  void lock(ActivePiece piece) {
    for (final cell in piece.cellsOnBoard()) {
      final target = cells[cell.row][cell.col];
      if (cell.kind == CellKind.full) {
        target
          ..full = piece.type.color
          ..bl = null
          ..tr = null;
      } else if (cell.tri == TriHalf.bl) {
        target.bl = piece.type.color;
      } else {
        target.tr = piece.type.color;
      }
    }
    revision++;
  }

  bool fillLowestCavity() {
    for (int row = config.rows - 1; row >= 0; row--) {
      for (int col = 0; col < config.cols; col++) {
        final cell = cells[row][col];
        if (cell.full != null) continue;
        final hasBl = cell.bl != null;
        final hasTr = cell.tr != null;
        if (hasBl == hasTr) continue;
        final color = hasBl ? cell.bl! : cell.tr!;
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
