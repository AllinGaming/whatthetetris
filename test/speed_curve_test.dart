import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/speed_curve.dart';

void main() {
  test('classic curve starts at 700ms and decays without an early cliff', () {
    expect(SpeedCurve.classic(1, 0).inMilliseconds, 700);

    final samples = [
      for (int level = 1; level <= 60; level++)
        SpeedCurve.classic(level, 0).inMilliseconds,
    ];

    // Monotonically non-increasing — never speeds back up as level rises.
    for (int i = 1; i < samples.length; i++) {
      expect(samples[i], lessThanOrEqualTo(samples[i - 1]));
    }
    // No early hard floor: still decreasing well past the old level-15 cliff.
    expect(samples[20], lessThan(samples[14]));
    // Never goes below (or exactly hits an unplayable) the sane floor.
    expect(samples.last, greaterThanOrEqualTo(SpeedCurve.floorMs));
  });

  test('arcade speed boost divides the base curve down to the same floor', () {
    final base = SpeedCurve.arcade(10, 0).inMilliseconds;
    final boosted = SpeedCurve.arcade(10, 5).inMilliseconds;
    expect(boosted, lessThan(base));
    expect(boosted, greaterThanOrEqualTo(SpeedCurve.floorMs));
  });

  test(
    'arcade is faster than classic by default, at every level, unboosted',
    () {
      for (int level = 1; level <= 30; level++) {
        final classicMs = SpeedCurve.classic(level, 0).inMilliseconds;
        final arcadeMs = SpeedCurve.arcade(level, 0).inMilliseconds;
        expect(
          arcadeMs,
          lessThanOrEqualTo(classicMs),
          reason:
              'level $level: arcade ($arcadeMs) should be at least as fast '
              'as classic ($classicMs)',
        );
      }
      // And meaningfully so partway through a run, not just marginally.
      expect(
        SpeedCurve.arcade(10, 0).inMilliseconds,
        lessThan(SpeedCurve.classic(10, 0).inMilliseconds * 0.8),
      );
    },
  );
}
