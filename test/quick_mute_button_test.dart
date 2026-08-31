import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatthetetris/services/audio_service.dart';
import 'package:whatthetetris/ui/widgets/quick_mute_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('quick mute toggles all audio and persists across the HUD', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final audio = await AudioService.create();
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QuickMuteButton(audio: audio)),
      ),
    );

    expect(find.byTooltip('Mute music and sound'), findsOneWidget);
    await tester.tap(find.byTooltip('Mute music and sound'));
    await tester.pumpAndSettle();

    expect(audio.muted, isTrue);
    expect(find.byTooltip('Unmute music and sound'), findsOneWidget);

    await tester.tap(find.byTooltip('Unmute music and sound'));
    await tester.pumpAndSettle();
    expect(audio.muted, isFalse);
  });
}
