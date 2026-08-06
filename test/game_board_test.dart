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

    board.lock(ActivePiece(type: triangle(TriHalf.bl), row: 1, col: 1));

    expect(board.cells[1][1].isFullyFilled, isTrue);
    expect(board.revision, 1);
  });

  test('cavity filler prioritizes the bottom-most incomplete cell', () {
    final board = GameBoard(const Config(rows: 3, cols: 2));
    board.cells[0][0].bl = Colors.blue;
    board.cells[2][1].tr = Colors.orange;

    expect(board.fillLowestCavity(), isTrue);
    expect(board.cells[2][1].isFullyFilled, isTrue);
    expect(board.cells[0][0].isFullyFilled, isFalse);
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
}
