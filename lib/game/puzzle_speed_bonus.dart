/// Shared completion-speed scoring for Daily Challenge and 2 Player Puzzle.
///
/// Only a successful solve earns this bonus. Active play starts after the
/// ready countdown; Daily's stopwatch already excludes pauses. Multiplayer
/// passes the host's round duration into the authoritative co-op engine.
abstract final class PuzzleSpeedBonus {
  static const maximum = 5000;
  static const pointsLostPerSecond = 10;

  static int forElapsed(Duration elapsed) {
    final seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
    return (maximum - seconds * pointsLostPerSecond).clamp(0, maximum);
  }
}
