import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whatthetetris/game/coop_game_engine.dart';
import 'package:whatthetetris/models/piece.dart';
import 'package:whatthetetris/services/multiplayer_session_service.dart';

void main() {
  group('cooperative game', () {
    test('red and blue permanently own complementary triangle halves', () {
      final engine = CoopGameEngine(seed: 42);

      expect(
        engine.activeFor(CoopPlayer.red)!.cellsOnBoard(),
        everyElement(
          isA<PieceCell>()
              .having((cell) => cell.kind, 'kind', CellKind.tri)
              .having((cell) => cell.tri, 'triangle', TriHalf.bl),
        ),
      );
      expect(
        engine.activeFor(CoopPlayer.blue)!.cellsOnBoard(),
        everyElement(
          isA<PieceCell>()
              .having((cell) => cell.kind, 'kind', CellKind.tri)
              .having((cell) => cell.tri, 'triangle', TriHalf.tr),
        ),
      );
      expect(
        CoopAction.values.map((action) => action.name),
        isNot(contains('mirror')),
      );
    });

    test('hard drops lock each player in only their assigned color', () {
      final engine = CoopGameEngine(seed: 7);

      expect(engine.applyAction(CoopPlayer.red, CoopAction.hardDrop), isTrue);
      expect(engine.applyAction(CoopPlayer.blue, CoopAction.hardDrop), isTrue);

      final occupied = engine.board.cells
          .expand((row) => row)
          .where(
            (cell) => cell.bl != null || cell.tr != null || cell.full != null,
          );
      expect(occupied, isNotEmpty);
      for (final cell in occupied) {
        if (cell.bl != null) expect(cell.bl, duoBlColor);
        if (cell.tr != null) expect(cell.tr, duoTrColor);
      }
    });

    test('snapshot round-trips the shared board and both falling pieces', () {
      final engine = CoopGameEngine(seed: 19);
      engine.board.cells[19][0].bl = duoBlColor;
      engine.board.cells[19][0].tr = duoTrColor;
      engine.board.cells[18][1].full = duoFullColor;

      final original = engine.snapshot();
      final restored = CoopGameSnapshot.fromJson(original.toJson());
      final board = restored.buildBoard();

      expect(restored.cells, original.cells);
      expect(restored.redPiece?.toJson(), original.redPiece?.toJson());
      expect(restored.bluePiece?.toJson(), original.bluePiece?.toJson());
      expect(
        restored.cavityChargesFor(CoopPlayer.red),
        original.cavityChargesFor(CoopPlayer.red),
      );
      expect(
        restored.cavityChargesFor(CoopPlayer.blue),
        original.cavityChargesFor(CoopPlayer.blue),
      );
      expect(board[19][0].bl, duoBlColor);
      expect(board[19][0].tr, duoTrColor);
      expect(board[18][1].full, duoFullColor);
    });

    test('both players start with one fill and only the clearer recharges', () {
      final engine = CoopGameEngine(seed: 23);

      expect(engine.cavityChargesFor(CoopPlayer.red), 1);
      expect(engine.cavityChargesFor(CoopPlayer.blue), 1);

      // Red spends their only charge on a cavity that does not clear a line.
      engine.board.cells[18][0].bl = duoBlColor;
      expect(engine.applyAction(CoopPlayer.red, CoopAction.fillCavity), isTrue);
      expect(engine.cavityChargesFor(CoopPlayer.red), 0);
      expect(engine.cavityChargesFor(CoopPlayer.blue), 1);

      // Blue completes the bottom line: Blue's spent charge is restored,
      // while Red does not receive a duplicate recharge.
      engine.board.cells[19][0].bl = duoBlColor;
      for (var col = 1; col < CoopGameEngine.config.cols; col++) {
        engine.board.cells[19][col].full = duoFullColor;
      }

      expect(
        engine.applyAction(CoopPlayer.blue, CoopAction.fillCavity),
        isTrue,
      );
      expect(engine.lines, 1);
      expect(engine.score, 100);
      expect(engine.cavityChargesFor(CoopPlayer.red), 0);
      expect(engine.cavityChargesFor(CoopPlayer.blue), 1);
      // Red's earlier filled cavity was one row above and correctly drops
      // into the new bottom row when Blue's completed row collapses.
      expect(engine.board.cells.last[0].bl, isNotNull);
      expect(engine.board.cells.last[0].tr, isNotNull);
    });

    test(
      'each snapshot calculates a landing ghost for either local player',
      () {
        final snapshot = CoopGameEngine(seed: 31).snapshot();

        final redGhost = snapshot.ghostFor(CoopPlayer.red);
        final blueGhost = snapshot.ghostFor(CoopPlayer.blue);

        expect(redGhost, isNotNull);
        expect(blueGhost, isNotNull);
        expect(
          redGhost!.row,
          greaterThan(snapshot.activeFor(CoopPlayer.red)!.row),
        );
        expect(
          blueGhost!.row,
          greaterThan(snapshot.activeFor(CoopPlayer.blue)!.row),
        );
      },
    );

    test('the shared game ends when the stack blocks the top', () {
      final engine = CoopGameEngine(seed: 3);
      for (final cell in engine.board.cells.first) {
        // Block red's spawn orientation without completing/clearing the row.
        cell.bl = duoBlColor;
      }

      engine.applyAction(CoopPlayer.red, CoopAction.hardDrop);

      expect(engine.gameOver, isTrue);
    });
  });

  group('room codes', () {
    test('generated codes are six readable characters', () {
      for (var seed = 0; seed < 100; seed++) {
        final code = MultiplayerSessionService.generateRoomCode(Random(seed));
        expect(code, hasLength(6));
        expect(MultiplayerSessionService.isValidRoomCode(code), isTrue);
        expect(code, isNot(contains(RegExp('[01IO]'))));
      }
    });

    test('validation accepts normalized codes and rejects malformed ones', () {
      expect(MultiplayerSessionService.isValidRoomCode(' abc234 '), isTrue);
      expect(MultiplayerSessionService.isValidRoomCode('ABC23'), isFalse);
      expect(MultiplayerSessionService.isValidRoomCode('ABC210'), isFalse);
    });
  });
}
