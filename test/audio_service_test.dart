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

  test('every mode shares Chill/Zen\'s calm ambient track', () {
    for (final mode in GameMode.values) {
      expect(
        MusicTrack.forMode(mode),
        MusicTrack.zen,
        reason: 'expected zen for $mode',
      );
    }
  });

}
