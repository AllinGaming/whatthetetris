import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/game/tutorial_level_screen.dart';
import 'package:whatthetetris/services/settings_service.dart';

/// The mobile TouchDpad's hero-button glow loops via AnimationController
/// .repeat() while enabled, which is correct in production but leaves
/// pumpAndSettle waiting for a frame that never stops being scheduled (see
/// the same reasoning in widget_test.dart). Flagging OS-level "reduce
/// motion" makes it settle on a static frame instead.
void _disableTestAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Pushes the tutorial level on top of a placeholder screen — Skip calls
/// `Navigator.maybePop`, which only actually pops when there's something to
/// pop back to, matching how every real caller pushes this screen.
Future<void> _pumpPushed(WidgetTester tester, {bool gestures = false}) async {
  _disableTestAnimations(tester);
  SharedPreferences.setMockInitialValues({
    if (gestures) 'settings_touch_control_scheme': 'gestures',
  });
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TutorialLevelScreen(settings: settings),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _advance(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 750));
}

void main() {
  testWidgets('starts on the Move & Rotate step', (tester) async {
    await _pumpPushed(tester);

    expect(
      find.textContaining('Move it'),
      findsOneWidget,
      reason: 'first step should ask the player to move/rotate the piece',
    );
  });

  testWidgets('walking through every step reaches the finish screen', (
    tester,
  ) async {
    await _pumpPushed(tester);

    // Step 1: Move & Rotate -> Hard Drop. Completion doesn't require the
    // move/rotate to have actually happened first (see _onLocked), so a
    // bare hard drop is enough to reliably advance in a test.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await _advance(tester);

    expect(find.textContaining('Mirror it'), findsOneWidget);

    // Step 2: Fusion -- mirror, then drop anywhere on the pre-placed row.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await _advance(tester);

    expect(find.textContaining('Hold this piece'), findsOneWidget);

    // Step 3: Hold.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    await _advance(tester);

    expect(find.textContaining('Fill that stray gap'), findsOneWidget);

    // Step 4: Cavity Fill.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pump();
    await _advance(tester);

    expect(find.text("You're ready — go play!"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Finish'), findsOneWidget);
  });

  testWidgets('Skip exits the level immediately from any step', (tester) async {
    await _pumpPushed(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(TutorialLevelScreen), findsNothing);
  });

  testWidgets('builds without exceptions at a small mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPushed(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a real keyboard viewport spells out the actual keys for the current '
    'step, since prose alone ("rotate it") doesn\'t say which key does that',
    (tester) async {
      await _pumpPushed(tester); // default test surface is wider than the
      // mobile breakpoint, so this exercises the keyboard hint scheme.

      expect(find.text('←'), findsOneWidget);
      expect(find.text('→'), findsOneWidget);
      expect(find.text('↑'), findsOneWidget);
      expect(find.text('Q'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
      expect(find.text('Rotate'), findsOneWidget);
    },
  );

  testWidgets(
    'gestures scheme on mobile shows an animated gesture hint instead of '
    'key glyphs -- there is no keyboard to reference on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpPushed(tester, gestures: true);

      expect(find.text('←'), findsNothing);
      expect(find.text('Move'), findsOneWidget);
      expect(find.text('Rotate'), findsOneWidget);
    },
  );
}
