import 'package:flutter/foundation.dart';

import '../game/speed_curve.dart';
import 'pieces.dart';

enum GameMode { chill, classic, arcade, sprint, ultra, zen, daily }

/// How a run ends, beyond the universal "stack tops out" rule every mode
/// still has as a fallback (docs/GDD.md SS5).
enum EndCondition {
  /// Ends only by topping out (Classic, Arcade) or never in practice
  /// because [GameModeConfig.softFloor] prevents topping out (Chill, Zen).
  topOut,

  /// Ends the instant [GameModeConfig.lineTarget] lines are cleared.
  lineTarget,

  /// Ends when [GameModeConfig.timeLimit] elapses.
  timeLimit,

  /// Ends — as a win — the instant every cell on the board is empty again.
  /// Pairs with a board that [GameModeConfig.startsPrefilled], since an
  /// empty-starting board would already satisfy this on the first frame.
  boardCleared,
}

/// Groups modes for the mode-select screen (docs/GDD.md SS5): Marathon,
/// Timed, Practice, or Daily.
enum ModeCategory { marathon, timed, practice, daily }

@immutable
class GameModeConfig {
  const GameModeConfig({
    required this.label,
    required this.description,
    required this.category,
    required this.hasCavityFiller,
    required this.hasManualSpeedBoost,
    required this.speedCurve,
    this.rows = 20,
    this.cols = 10,
    this.pieceNames,
    this.softFloor = false,
    this.endCondition = EndCondition.topOut,
    this.lineTarget,
    this.timeLimit,
    this.startingCavityCharges = 1,
    this.useDailySeed = false,
    this.startsPrefilled = false,
  });

  final String label;
  final String description;
  final ModeCategory category;
  final bool hasCavityFiller;
  final bool hasManualSpeedBoost;
  final Duration Function(int level, int speedBoost) speedCurve;

  /// Board height. Every mode keeps the standard 20 except Daily, which
  /// shrinks it to keep its prefilled puzzle (half the board) smaller and
  /// less overwhelming to fully clear.
  final int rows;

  /// Board width. Chill and Daily use a narrower board (readability for
  /// Chill, an easier puzzle for Daily); every other mode keeps the
  /// standard 10.
  final int cols;

  /// Restricts the piece bag to a named subset (see [Pieces.byNames]).
  /// Null means the full seven-piece catalog.
  final List<String>? pieceNames;

  /// If true, a spawn that would otherwise top out instead clears space at
  /// the top of the board rather than ending the run (docs/GDD.md SS5).
  final bool softFloor;

  final EndCondition endCondition;
  final int? lineTarget;
  final Duration? timeLimit;
  final int startingCavityCharges;

  /// If true, the run's piece-bag seed comes from today's date
  /// (see DailyChallengeService.seedForToday) instead of a random draw.
  final bool useDailySeed;

  /// If true, the board starts roughly half-filled with a deterministic
  /// puzzle layout (same seed as [useDailySeed]) instead of empty, and the
  /// run is won by clearing it back down to nothing — see
  /// [EndCondition.boardCleared].
  final bool startsPrefilled;

  static const chill = GameModeConfig(
    label: 'Chill',
    description:
        'The easy on-ramp: a narrower board, five simpler shapes, and a '
        'speed curve that actually levels off instead of climbing forever. '
        'Play at your own pace — the board clears space instead of ending '
        'your run.',
    category: ModeCategory.marathon,
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.chill,
    cols: 8,
    pieceNames: ['I4', 'O4', 'T4', 'L4', 'J4'],
    softFloor: true,
    startingCavityCharges: 2,
  );

  static const classic = GameModeConfig(
    label: 'Classic',
    description:
        'Straight Tetris pacing on a steady, predictable speed curve. '
        'Cavity fillers included — no speed-boost stacking.',
    category: ModeCategory.marathon,
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.classic,
  );

  static const arcade = GameModeConfig(
    label: 'Arcade',
    description:
        'The full chaos: a faster, steeper speed curve from the start, '
        'plus stackable speed boosts for risk/reward scoring.',
    category: ModeCategory.marathon,
    hasCavityFiller: true,
    hasManualSpeedBoost: true,
    speedCurve: SpeedCurve.arcade,
  );

  static final sprint = GameModeConfig(
    label: 'Sprint',
    description:
        'Clear 40 lines as fast as you can. Fixed pace, no escalation — '
        'the clock is the only thing coming for you.',
    category: ModeCategory.timed,
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.fixed(500),
    endCondition: EndCondition.lineTarget,
    lineTarget: 40,
  );

  static final ultra = GameModeConfig(
    label: 'Ultra',
    description:
        'Two minutes on the clock. Score as much as you can before time '
        'runs out, on the familiar Classic curve.',
    category: ModeCategory.timed,
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.classic,
    endCondition: EndCondition.timeLimit,
    timeLimit: Duration(minutes: 2),
  );

  static final zen = GameModeConfig(
    label: 'Zen',
    description:
        'No escalation, no game over. Practice fusion timing and mirror '
        'usage with zero stakes.',
    category: ModeCategory.practice,
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.fixed(650),
    softFloor: true,
    startingCavityCharges: 3,
  );

  static const daily = GameModeConfig(
    label: 'Daily Challenge',
    description:
        'A half-filled board, the same one for everyone who plays today — '
        'clear it completely to win. Come back tomorrow for a new layout.',
    category: ModeCategory.daily,
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.classic,
    rows: 16,
    cols: 8,
    useDailySeed: true,
    startsPrefilled: true,
    endCondition: EndCondition.boardCleared,
  );
}

extension GameModeConfigX on GameMode {
  GameModeConfig get config => switch (this) {
    GameMode.chill => GameModeConfig.chill,
    GameMode.classic => GameModeConfig.classic,
    GameMode.arcade => GameModeConfig.arcade,
    GameMode.sprint => GameModeConfig.sprint,
    GameMode.ultra => GameModeConfig.ultra,
    GameMode.zen => GameModeConfig.zen,
    GameMode.daily => GameModeConfig.daily,
  };
}
