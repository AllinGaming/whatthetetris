import 'package:flutter/foundation.dart';

import '../game/speed_curve.dart';
import 'pieces.dart';

enum GameMode { chill, classic, arcade, sprint, ultra, zen, daily }

/// How a run ends, beyond the universal "stack tops out" rule every mode
/// still has as a fallback (docs/GDD.md SS5).
enum EndCondition {
  /// Ends only by topping out (Classic, Arcade) or never in practice
  /// because [GameModeConfig.softFloor] prevents topping out (Zen).
  topOut,

  /// Ends the instant [GameModeConfig.lineTarget] lines are cleared.
  lineTarget,

  /// Ends when [GameModeConfig.timeLimit] elapses.
  timeLimit,

  /// Ends — as a win — once the locked stack occupies no more than one row.
  /// Pairs with a board that [GameModeConfig.startsPrefilled] with at least
  /// two occupied rows.
  boardReducedToOneRow,
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
  /// shrinks it to keep its prefilled puzzle smaller and easier to read.
  final int rows;

  /// Board width. The player-facing Classic and Daily use a narrower board
  /// (readability for Classic, an easier puzzle for Daily); other modes keep the
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

  /// If true, the board starts partially filled with a deterministic
  /// puzzle layout (same seed as [useDailySeed]) instead of empty, and the
  /// run is won by reducing the locked stack to one occupied row — see
  /// [EndCondition.boardReducedToOneRow].
  final bool startsPrefilled;

  static const chill = GameModeConfig(
    // Keep the existing enum/storage key so current Chill players retain
    // their local bests while the player-facing mode becomes Classic.
    label: 'Classic',
    description:
        'Relaxed endless play on a narrower board with five familiar shapes. '
        'The pace levels off, but reaching the top still ends the game.',
    category: ModeCategory.marathon,
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.chill,
    cols: 8,
    pieceNames: ['I4', 'O4', 'T4', 'L4', 'J4'],
    softFloor: false,
    startingCavityCharges: 2,
  );

  static const classic = GameModeConfig(
    label: 'Legacy Classic',
    description:
        'Straight falling-block pacing on a steady, predictable speed curve. '
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
        'A new formation up to 7 rows high, shared by everyone today. Leave '
        'only one occupied row to win, then replay to improve your score.',
    category: ModeCategory.daily,
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.chill,
    rows: 16,
    cols: 8,
    pieceNames: ['I4', 'O4', 'T4', 'L4', 'J4'],
    startingCavityCharges: 2,
    useDailySeed: true,
    startsPrefilled: true,
    endCondition: EndCondition.boardReducedToOneRow,
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
