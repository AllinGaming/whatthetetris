import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/services/audio_service.dart';

void main() {
  test('achievement unlock is its own SFX, not an alias of another one', () {
    expect(Sfx.values, contains(Sfx.achievementUnlock));
  });

  test(
    'every sound effect maps to a unique packaged non-empty asset',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final assets = Sfx.values.map((sfx) => sfx.asset).toList();

      expect(assets.toSet(), hasLength(Sfx.values.length));
      for (final asset in assets) {
        final bytes = await rootBundle.load('assets/audio/$asset');
        expect(bytes.lengthInBytes, greaterThan(1000), reason: asset);
      }
    },
  );

  test('music is quieter than effects by default', () {
    expect(
      AudioService.defaultMusicVolume,
      lessThan(AudioService.defaultSfxVolume),
    );
  });

  test('every mode shares the supplied gameplay track', () {
    for (final mode in GameMode.values) {
      expect(
        MusicTrack.forMode(mode),
        MusicTrack.gameplay,
        reason: 'expected the shared gameplay track for $mode',
      );
    }
  });

  test('the custom tmusic asset is the looping menu track', () {
    expect(MusicTrack.menu.asset, 'tmusic.mp3');
  });

  test('the supplied MP3 is the looping gameplay track', () {
    expect(MusicTrack.gameplay.asset, 'zen_classic_arcade_music.mp3');
  });
}
