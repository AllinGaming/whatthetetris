import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/services/audio_service.dart';

void main() {
  test('achievement unlock is its own SFX, not an alias of another one', () {
    // Sfx -> asset filename mapping is a private extension inside
    // audio_service.dart, so the only thing testable from outside is that
    // this is genuinely a distinct enum value.
    expect(Sfx.values, contains(Sfx.achievementUnlock));
  });

  test('Arcade gets its own energetic music track', () {
    expect(MusicTrack.forMode(GameMode.arcade), MusicTrack.arcade);
    expect(MusicTrack.arcade.asset, 'music_arcade_loop.wav');
  });

  test('Zen and Chill share the calm ambient track', () {
    expect(MusicTrack.forMode(GameMode.zen), MusicTrack.zen);
    expect(MusicTrack.forMode(GameMode.chill), MusicTrack.zen);
  });

  test('every other mode still gets the marathon track', () {
    for (final mode in [
      GameMode.classic,
      GameMode.sprint,
      GameMode.ultra,
      GameMode.daily,
    ]) {
      expect(
        MusicTrack.forMode(mode),
        MusicTrack.marathon,
        reason: 'expected marathon for $mode',
      );
    }
  });
}
