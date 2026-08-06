import 'dart:math';

import '../models/piece.dart';
import '../models/pieces.dart';

/// A standard seven-bag randomizer.
///
/// Every group of seven draws contains every piece exactly once. Injecting a
/// seeded [Random] makes sessions reproducible for tests, replays, and future
/// daily challenges.
class PieceBag {
  PieceBag({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<PieceDefinition> _pending = [];

  PieceDefinition take() {
    _ensureAvailable(1);
    return _pending.removeAt(0);
  }

  List<PieceDefinition> takeMany(int count) {
    assert(count >= 0);
    _ensureAvailable(count);
    return List.generate(count, (_) => _pending.removeAt(0));
  }

  void reset() => _pending.clear();

  void _ensureAvailable(int count) {
    while (_pending.length < count) {
      final bag = List<PieceDefinition>.of(Pieces.all)..shuffle(_random);
      _pending.addAll(bag);
    }
  }
}
