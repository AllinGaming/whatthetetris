import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatthetetris/game/game_board.dart';
import 'package:whatthetetris/models/active_piece.dart';
import 'package:whatthetetris/models/board.dart';
import 'package:whatthetetris/models/piece.dart';

void main() {
  PieceDefinition triangle(TriHalf half) => PieceDefinition(
    name: half.name,
    base: [PieceCell(row: 0, col: 0, kind: CellKind.tri, tri: half)],
    color: Colors.cyan,
  );

  test('opposite triangle halves can share a cell', () {
    final board = GameBoard(const Config(rows: 2, cols: 2));
    board.cells[0][0].tr = Colors.pink;

    expect(
      board.canPlace(ActivePiece(type: triangle(TriHalf.bl), row: 0, col: 0)),
      isTrue,
    );
    expect(
      board.canPlace(ActivePiece(type: triangle(TriHalf.tr), row: 0, col: 0)),
      isFalse,
    );
  });

  test('locking complementary halves completes a cell', () {
    final board = GameBoard(const Config(rows: 2, cols: 2));
    board.cells[1][1].tr = Colors.pink;

    board.lock(
      ActivePiece(type: triangle(TriHalf.bl), row: 1, col: 1),
      colorForCell: (_) => Colors.cyan,
    );

    expect(board.cells[1][1].isFullyFilled, isTrue);
    expect(board.revision, 1);
  });

  test('cavity filler prioritizes the bottom-most incomplete cell', () {
    final board = GameBoard(const Config(rows: 3, cols: 2));
    board.cells[0][0].bl = Colors.blue;
    board.cells[2][1].tr = Colors.orange;

    expect(board.fillLowestCavity(colorForFill: (_, existing) => existing), (
      row: 2,
      col: 1,
    ));
    expect(board.cells[2][1].isFullyFilled, isTrue);
    expect(board.cells[0][0].isFullyFilled, isFalse);
  });

  test('fillLowestCavity returns null when there is no cavity to fill', () {
    final board = GameBoard(const Config(rows: 2, cols: 2));

    expect(
      board.fillLowestCavity(colorForFill: (_, existing) => existing),
      isNull,
    );
  });

  test('fillCavityAt fills the targeted cell, not just the lowest one', () {
    final board = GameBoard(const Config(rows: 3, cols: 2));
    board.cells[0][0].bl = Colors.blue;
    board.cells[2][1].tr = Colors.orange;

    // The lowest cavity is (2,1), but this targets (0,0) specifically.
    expect(
      board.fillCavityAt(0, 0, colorForFill: (_, existing) => existing),
      isTrue,
    );
    expect(board.cells[0][0].isFullyFilled, isTrue);
    expect(board.cells[2][1].isFullyFilled, isFalse);
  });

  test('fillCavityAt returns false for a non-cavity cell', () {
    final board = GameBoard(const Config(rows: 2, cols: 2));
    board.cells[0][0].bl = Colors.blue;
    board.cells[0][0].tr = Colors.blue; // already complete
    board.cells[1][1].full = Colors.red;

    expect(
      board.fillCavityAt(0, 0, colorForFill: (_, existing) => existing),
      isFalse,
      reason: 'already-complete cell has no cavity to fill',
    );
    expect(
      board.fillCavityAt(1, 1, colorForFill: (_, existing) => existing),
      isFalse,
      reason: 'a full cell has no cavity to fill',
    );
    expect(
      board.fillCavityAt(0, 1, colorForFill: (_, existing) => existing),
      isFalse,
      reason: 'a fully empty cell has no cavity to fill',
    );
  });

  test('fillCavityAt returns false for an out-of-bounds cell', () {
    final board = GameBoard(const Config(rows: 2, cols: 2));

    expect(
      board.fillCavityAt(-1, 0, colorForFill: (_, existing) => existing),
      isFalse,
    );
    expect(
      board.fillCavityAt(0, 5, colorForFill: (_, existing) => existing),
      isFalse,
    );
  });

  test('countFusions counts halves that complete against existing cells', () {
    final board = GameBoard(const Config(rows: 2, cols: 2));
    board.cells[0][0].tr = Colors.pink;

    // Landing a bl-half onto an empty cell fuses nothing.
    expect(
      board.countFusions(
        ActivePiece(type: triangle(TriHalf.bl), row: 1, col: 1),
      ),
      0,
    );
    // Landing a bl-half where a tr-half already sits fuses one cell.
    expect(
      board.countFusions(
        ActivePiece(type: triangle(TriHalf.bl), row: 0, col: 0),
      ),
      1,
    );
  });

  test('clearTopRows wipes rows in place without shifting the rest', () {
    final board = GameBoard(const Config(rows: 3, cols: 2));
    for (final cell in board.cells[0]) {
      cell.bl = Colors.white;
    }
    board.cells[2][0].bl = Colors.green;

    board.clearTopRows(1);

    expect(board.cells[0].every((cell) => cell.bl == null), isTrue);
    expect(board.cells[2][0].bl, Colors.green);
    expect(board.revision, 1);
  });

  test('isNearTop detects any content in the top N rows', () {
    final board = GameBoard(const Config(rows: 10, cols: 2));
    expect(board.isNearTop(), isFalse);

    board.cells[3][0].bl = Colors.red;
    expect(board.isNearTop(rows: 4), isTrue);
    expect(board.isNearTop(rows: 2), isFalse);

    board.cells[9][0].bl = Colors.red;
    expect(board.isNearTop(rows: 4), isTrue); // still true from row 3
  });

  test('collapsing a row shifts preserved cells down', () {
    final board = GameBoard(const Config(rows: 4, cols: 2));
    for (final cell in board.cells[3]) {
      cell
        ..bl = Colors.white
        ..tr = Colors.white;
    }
    board.cells[2][0].bl = Colors.green;

    expect(board.detectFullRows(), [3]);
    board.collapseRows([3]);

    expect(board.cells[0].every((cell) => !cell.isFullyFilled), isTrue);
    expect(board.cells[3][0].bl, Colors.green);
    expect(board.detectFullRows(), isEmpty);
  });

  test('isEmpty reflects full/bl/tr occupancy across the whole board', () {
    final board = GameBoard(const Config(rows: 2, cols: 2));
    expect(board.isEmpty, isTrue);

    board.cells[1][1].bl = Colors.red;
    expect(board.isEmpty, isFalse);

    board.cells[1][1].bl = null;
    expect(board.isEmpty, isTrue);
  });

  test('seedPuzzle only fills the bottom half, leaving the top empty', () {
    final board = GameBoard(const Config(rows: 10, cols: 6));
    board.seedPuzzle(Random(1), (kind, tri) => Colors.grey);

    for (int row = 0; row < 5; row++) {
      expect(
        board.cells[row].every(
          (c) => c.full == null && c.bl == null && c.tr == null,
        ),
        isTrue,
        reason: 'row $row is above the puzzle zone and should stay empty',
      );
    }
    expect(board.isEmpty, isFalse); // the bottom half actually got filled
  });

  test('seedPuzzle never leaves a row completely full', () {
    // A high fill chance stresses the retry-until-not-full loop harder than
    // the puzzle's real ~55% rate would.
    for (final seed in [1, 2, 3, 4, 5]) {
      final board = GameBoard(const Config(rows: 10, cols: 6));
      board.seedPuzzle(Random(seed), (kind, tri) => Colors.grey);
      expect(board.detectFullRows(), isEmpty);
    }
  });

  test('seedPuzzle never fills both triangle halves of one cell at once', () {
    final board = GameBoard(const Config(rows: 10, cols: 6));
    board.seedPuzzle(Random(7), (kind, tri) => Colors.grey);

    for (final row in board.cells) {
      for (final cell in row) {
        expect(cell.bl != null && cell.tr != null, isFalse);
      }
    }
  });
}
