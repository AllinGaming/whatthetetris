import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/puzzle_speed_bonus.dart';

void main() {
  test('puzzle speed bonus starts at its cap and loses ten per second', () {
    expect(PuzzleSpeedBonus.forElapsed(Duration.zero), 5000);
    expect(PuzzleSpeedBonus.forElapsed(const Duration(seconds: 1)), 4990);
    expect(PuzzleSpeedBonus.forElapsed(const Duration(minutes: 1)), 4400);
    expect(PuzzleSpeedBonus.forElapsed(const Duration(minutes: 5)), 2000);
  });

  test('puzzle speed bonus never becomes negative', () {
    expect(PuzzleSpeedBonus.forElapsed(const Duration(minutes: 20)), 0);
  });

  test('negative elapsed values are safely treated as zero', () {
    expect(PuzzleSpeedBonus.forElapsed(const Duration(seconds: -2)), 5000);
  });
}
