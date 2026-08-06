import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whatthetetris/game/piece_bag.dart';
import 'package:whatthetetris/models/pieces.dart';

void main() {
  test('each seven-bag contains every piece exactly once', () {
    final bag = PieceBag(random: Random(42));

    for (int bagIndex = 0; bagIndex < 10; bagIndex++) {
      final names = bag.takeMany(7).map((piece) => piece.name).toSet();
      expect(names, Pieces.all.map((piece) => piece.name).toSet());
    }
  });

  test('a seed reproduces the same piece sequence', () {
    final first = PieceBag(random: Random(7));
    final second = PieceBag(random: Random(7));

    expect(
      first.takeMany(50).map((piece) => piece.name),
      second.takeMany(50).map((piece) => piece.name),
    );
  });

  test('reset discards the current partial bag', () {
    final bag = PieceBag(random: Random(12));
    bag.takeMany(3);
    bag.reset();

    expect(bag.takeMany(7).map((piece) => piece.name).toSet(), hasLength(7));
  });
}
