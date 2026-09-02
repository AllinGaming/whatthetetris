import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/services/audio_service.dart';
import 'package:whatthetetris/services/live_services.dart';
import 'package:whatthetetris/services/settings_service.dart';
import 'package:whatthetetris/services/theme_service.dart';
import 'package:whatthetetris/ui/settings_screen.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester) async {
    // Tall enough that the whole ListView (including Cloud Backup near the
    // bottom) is actually built, not just scrolled-past — ListView(children:)
    // only materializes what's within the viewport/cache extent.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final audio = await AudioService.create();
    final settings = await SettingsService.create();
    final theme = await ThemeService.create();
    final live = await LiveServices.create();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          audio: audio,
          settings: settings,
          theme: theme,
          live: live,
        ),
      ),
    );
  }

  testWidgets('every section renders as a labeled card, not a bare list', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('AUDIO'), findsOneWidget);
    expect(find.text('ACCESSIBILITY'), findsOneWidget);
    expect(find.text('CLOUD BACKUP'), findsOneWidget);
    expect(find.text('LEGAL'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
  });

  testWidgets('volume and UI-scale sliders show a live percentage at rest', (
    tester,
  ) async {
    await pumpSettings(tester);

    // Defaults: AudioService music/sfx volume 0.25/0.9, SettingsService
    // uiScale 1.0 — all three should read a resting value, not just show a
    // bubble while dragging.
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('each row carries an identifying icon', (tester) async {
    await pumpSettings(tester);

    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(find.byIcon(Icons.motion_photos_off), findsOneWidget);
    expect(find.byIcon(Icons.vibration), findsOneWidget);
    expect(find.byIcon(Icons.text_fields), findsOneWidget);
    expect(find.byIcon(Icons.touch_app), findsOneWidget);
  });
}
