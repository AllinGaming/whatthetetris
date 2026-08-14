import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/replay.dart';
import 'package:whatthetetris/models/game_mode.dart';

void main() {
  test('a recorded run serializes and deserializes back to itself', () {
    final recorder = ReplayRecorder(seed: 42, mode: GameMode.classic);
    recorder.record(ReplayInputType.moveLeft, 120);
    recorder.record(ReplayInputType.rotateRight, 340);
    recorder.record(ReplayInputType.mirror, 500);
    recorder.record(ReplayInputType.hardDrop, 900);

    final replay = recorder.build();
    final roundTripped = Replay.fromJson(replay.toJson());

    expect(roundTripped.version, replay.version);
    expect(roundTripped.seed, 42);
    expect(roundTripped.mode, GameMode.classic);
    expect(roundTripped.events.length, 4);
    for (var i = 0; i < replay.events.length; i++) {
      expect(roundTripped.events[i].atMs, replay.events[i].atMs);
      expect(roundTripped.events[i].type, replay.events[i].type);
    }
  });

  test('an empty replay round-trips cleanly', () {
    final recorder = ReplayRecorder(seed: 7, mode: GameMode.sprint);
    final replay = recorder.build();
    final roundTripped = Replay.fromJson(replay.toJson());

    expect(roundTripped.events, isEmpty);
    expect(roundTripped.mode, GameMode.sprint);
  });
}
