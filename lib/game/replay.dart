import '../models/game_mode.dart';

/// Every player-initiated action the board reacts to. Gravity ticks and
/// lock-delay expiry are deliberately excluded — they're a pure function of
/// elapsed time plus this event list, so re-deriving them on playback keeps
/// the format small.
enum ReplayInputType {
  moveLeft,
  moveRight,
  softDrop,
  rotateLeft,
  rotateRight,
  mirror,
  hold,
  hardDrop,
  cavityFill,
  speedUp,
}

/// One input, timestamped by milliseconds elapsed since the run started.
class ReplayEvent {
  const ReplayEvent({required this.atMs, required this.type});

  final int atMs;
  final ReplayInputType type;

  Map<String, dynamic> toJson() => {'atMs': atMs, 'type': type.name};

  static ReplayEvent fromJson(Map<String, dynamic> json) => ReplayEvent(
    atMs: json['atMs'] as int,
    type: ReplayInputType.values.byName(json['type'] as String),
  );
}

/// A versioned, serializable recording of one run: the seed the piece bag
/// was drawn from, the mode (which determines the piece pool and speed
/// curve), and the ordered input log. Because the piece bag is already
/// seedable (see piece_bag.dart), `(seed, mode, events)` is enough to
/// deterministically reconstruct an entire run.
///
/// This is groundwork for validated leaderboards and Daily Challenge
/// (docs/TECHNICAL_ARCHITECTURE.md SS4) — a server can re-simulate a replay
/// before trusting a submitted score. Nothing consumes this yet; it exists
/// so that work doesn't require touching gameplay code again later.
class Replay {
  const Replay({
    required this.version,
    required this.seed,
    required this.mode,
    required this.events,
  });

  static const currentVersion = 1;

  final int version;
  final int seed;
  final GameMode mode;
  final List<ReplayEvent> events;

  Map<String, dynamic> toJson() => {
    'version': version,
    'seed': seed,
    'mode': mode.name,
    'events': events.map((e) => e.toJson()).toList(),
  };

  static Replay fromJson(Map<String, dynamic> json) => Replay(
    version: json['version'] as int,
    seed: json['seed'] as int,
    mode: GameMode.values.byName(json['mode'] as String),
    events: (json['events'] as List)
        .map((e) => ReplayEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Records input events during a live run, timestamped against a shared
/// clock the caller owns (so pausing the game pauses the replay clock too).
class ReplayRecorder {
  ReplayRecorder({required this.seed, required this.mode});

  final int seed;
  final GameMode mode;
  final List<ReplayEvent> _events = [];

  void record(ReplayInputType type, int atMs) {
    _events.add(ReplayEvent(atMs: atMs, type: type));
  }

  Replay build() => Replay(
    version: Replay.currentVersion,
    seed: seed,
    mode: mode,
    events: List.unmodifiable(_events),
  );
}
