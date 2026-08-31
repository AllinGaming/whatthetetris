import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/models/game_mode.dart';

void main() {
  test('the relaxed rules are the player-facing Classic mode', () {
    expect(GameMode.chill.config.label, 'Classic');
    expect(GameMode.chill.config.cols, 8);
    expect(GameMode.chill.config.softFloor, isFalse);
    expect(GameMode.chill.config.endCondition, EndCondition.topOut);
    expect(GameMode.classic.config.label, 'Legacy Classic');
  });

  test('Daily Challenge uses the easier Classic shape and pace settings', () {
    final daily = GameMode.daily.config;
    final classic = GameMode.chill.config;

    expect(daily.pieceNames, classic.pieceNames);
    expect(daily.startingCavityCharges, classic.startingCavityCharges);
    expect(daily.speedCurve(1, 0), classic.speedCurve(1, 0));
    expect(daily.speedCurve(20, 0), classic.speedCurve(20, 0));
    expect(daily.startsPrefilled, isTrue);
    expect(daily.endCondition, EndCondition.boardReducedToOneRow);
  });
}
