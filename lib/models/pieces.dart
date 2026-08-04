import 'package:flutter/material.dart';

import 'piece.dart';

List<PieceCell> _triangulate(
  List<({int row, int col})> squares, {
  TriHalf tri = TriHalf.bl,
}) {
  // Convert each square coordinate to a single triangle (uniform diagonal)
  // so an entire piece shares one orientation and flips together on rotate.
  return squares
      .map(
        (sq) => PieceCell(row: sq.row, col: sq.col, kind: CellKind.tri, tri: tri),
      )
      .toList();
}

/// The full catalog of playable pieces, built once.
class Pieces {
  const Pieces._();

  static final List<PieceDefinition> all = [
    PieceDefinition(
      name: 'I4',
      base: _triangulate([
        (row: 0, col: 0),
        (row: 0, col: 1),
        (row: 0, col: 2),
        (row: 0, col: 3),
      ]),
      color: const Color(0xFF8AE66E),
    ),
    PieceDefinition(
      name: 'L4',
      base: _triangulate([
        (row: 0, col: 0),
        (row: 1, col: 0),
        (row: 2, col: 0),
        (row: 2, col: 1),
      ]),
      color: const Color(0xFF9B7BFF),
    ),
    PieceDefinition(
      name: 'T4',
      base: _triangulate([
        (row: 0, col: 0),
        (row: 0, col: 1),
        (row: 0, col: 2),
        (row: 1, col: 1),
      ]),
      color: const Color(0xFFFF8FB1),
    ),
    PieceDefinition(
      name: 'O4',
      base: _triangulate([
        (row: 0, col: 0),
        (row: 0, col: 1),
        (row: 1, col: 0),
        (row: 1, col: 1),
      ]),
      color: const Color(0xFFFFE066),
    ),
    PieceDefinition(
      name: 'S4',
      base: _triangulate([
        (row: 0, col: 1),
        (row: 0, col: 2),
        (row: 1, col: 0),
        (row: 1, col: 1),
      ]),
      color: const Color(0xFF66E0F4),
    ),
    PieceDefinition(
      name: 'Z4',
      base: _triangulate([
        (row: 0, col: 0),
        (row: 0, col: 1),
        (row: 1, col: 1),
        (row: 1, col: 2),
      ]),
      color: const Color(0xFFFF6E6E),
    ),
    PieceDefinition(
      name: 'J4',
      base: _triangulate([
        (row: 0, col: 1),
        (row: 1, col: 1),
        (row: 2, col: 1),
        (row: 2, col: 0),
      ]),
      color: const Color(0xFF6E8CFF),
    ),
  ];
}
