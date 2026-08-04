import 'piece.dart';

class ActivePiece {
  ActivePiece({
    required this.type,
    this.rotation = 0,
    required this.row,
    required this.col,
    this.mirrored = false,
  });

  final PieceDefinition type;
  final int rotation;
  final int row;
  final int col;
  final bool mirrored;

  ActivePiece copyWith({int? rotation, int? row, int? col, bool? mirrored}) {
    return ActivePiece(
      type: type,
      rotation: rotation ?? this.rotation,
      row: row ?? this.row,
      col: col ?? this.col,
      mirrored: mirrored ?? this.mirrored,
    );
  }

  /// This piece's cells translated to absolute board coordinates at its
  /// current rotation, applying the mirror flip if active.
  List<PieceCell> cellsOnBoard() {
    final rot = type.rotations[rotation % type.rotations.length];
    return rot
        .map(
          (c) => PieceCell(
            row: row + c.row,
            col: col + c.col,
            kind: c.kind,
            tri: mirrored ? c.tri?.rotateCW() : c.tri,
          ),
        )
        .toList();
  }
}
