import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/models/pieces.dart';

void main() {
  test('catalog has 7 uniquely-named pieces, each with 4 cells', () {
    expect(Pieces.all.length, 7);
    expect(Pieces.all.map((p) => p.name).toSet().length, 7);
    for (final piece in Pieces.all) {
      expect(piece.rotations.length, 4);
      for (final rotation in piece.rotations) {
        expect(rotation.length, 4, reason: '${piece.name} must have 4 cells');
        expect(
          rotation.map((c) => (c.row, c.col)).toSet().length,
          4,
          reason: '${piece.name} cells must not overlap',
        );
      }
    }
  });

  test('every rotation stays within a 4x4 bounding box', () {
    for (final piece in Pieces.all) {
      for (final rotation in piece.rotations) {
        final maxRow = rotation.map((c) => c.row).reduce((a, b) => a > b ? a : b);
        final maxCol = rotation.map((c) => c.col).reduce((a, b) => a > b ? a : b);
        expect(rotation.every((c) => c.row >= 0 && c.col >= 0), isTrue);
        expect(maxRow, lessThan(4));
        expect(maxCol, lessThan(4));
      }
    }
  });
}
