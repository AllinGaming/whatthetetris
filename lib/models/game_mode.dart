import 'package:flutter/foundation.dart';

import '../game/speed_curve.dart';

enum GameMode { classic, arcade }

@immutable
class GameModeConfig {
  const GameModeConfig({
    required this.label,
    required this.description,
    required this.hasCavityFiller,
    required this.hasManualSpeedBoost,
    required this.speedCurve,
  });

  final String label;
  final String description;
  final bool hasCavityFiller;
  final bool hasManualSpeedBoost;
  final Duration Function(int level, int speedBoost) speedCurve;

  static const classic = GameModeConfig(
    label: 'Classic',
    description:
        'Straight Tetris pacing on a steady, predictable speed curve. '
        'Cavity fillers included — no speed-boost stacking.',
    hasCavityFiller: true,
    hasManualSpeedBoost: false,
    speedCurve: SpeedCurve.classic,
  );

  static const arcade = GameModeConfig(
    label: 'Arcade',
    description:
        'The full chaos: a faster, steeper speed curve from the start, '
        'plus stackable speed boosts for risk/reward scoring.',
    hasCavityFiller: true,
    hasManualSpeedBoost: true,
    speedCurve: SpeedCurve.arcade,
  );
}

extension GameModeConfigX on GameMode {
  GameModeConfig get config => switch (this) {
    GameMode.classic => GameModeConfig.classic,
    GameMode.arcade => GameModeConfig.arcade,
  };
}
