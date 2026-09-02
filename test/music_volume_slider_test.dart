import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/services/audio_service.dart';
import 'package:whatthetetris/ui/widgets/music_volume_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('menu music slider shows and persists the selected volume', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final audio = await AudioService.create();
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MusicVolumeSlider(audio: audio)),
      ),
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.6);
    await tester.pumpAndSettle();

    expect(audio.musicVolume, 0.6);
    expect(find.text('60%'), findsOneWidget);
  });
}
