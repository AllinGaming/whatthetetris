enum CoopVariant {
  fixed,
  mirror;

  bool get allowsMirror => this == CoopVariant.mirror;

  String get title => switch (this) {
    CoopVariant.fixed => '2 Player',
    CoopVariant.mirror => '2 Player Mirror',
  };

  String get leaderboardKey => switch (this) {
    CoopVariant.fixed => 'multiplayer',
    CoopVariant.mirror => 'multiplayerMirror',
  };

  String get analyticsName => switch (this) {
    CoopVariant.fixed => 'fixed',
    CoopVariant.mirror => 'mirror',
  };

  static CoopVariant fromName(Object? value) => CoopVariant.values.firstWhere(
    (variant) => variant.name == value,
    orElse: () => CoopVariant.fixed,
  );
}
