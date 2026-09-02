enum CoopVariant {
  fixed,
  mirror,
  puzzle;

  bool get allowsMirror => this != CoopVariant.fixed;

  bool get isPuzzle => this == CoopVariant.puzzle;

  int get startingCavityCharges => isPuzzle ? 2 : 1;

  String get title => switch (this) {
    CoopVariant.fixed => '2 Player',
    CoopVariant.mirror => '2 Player Mirror',
    CoopVariant.puzzle => '2 Player Puzzle',
  };

  String get leaderboardKey => switch (this) {
    CoopVariant.fixed => 'multiplayer',
    CoopVariant.mirror => 'multiplayerMirror',
    CoopVariant.puzzle => 'multiplayerPuzzle',
  };

  String get analyticsName => switch (this) {
    CoopVariant.fixed => 'fixed',
    CoopVariant.mirror => 'mirror',
    CoopVariant.puzzle => 'puzzle',
  };

  String get featureName => switch (this) {
    CoopVariant.fixed => 'multiplayer',
    CoopVariant.mirror => 'multiplayer_mirror',
    CoopVariant.puzzle => 'multiplayer_puzzle',
  };

  static CoopVariant fromName(Object? value) => CoopVariant.values.firstWhere(
    (variant) => variant.name == value,
    orElse: () => CoopVariant.fixed,
  );
}
