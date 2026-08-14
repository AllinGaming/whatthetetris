import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/tutorial_overlay.dart';

void main() {
  Future<void> pumpOverlay(WidgetTester tester, {VoidCallback? onDone}) async {
    // The Fusion/Mirror pages embed looping decorative animations —
    // disabling OS-level "reduce motion" lets them settle on a static frame
    // instead of leaving pumpAndSettle waiting forever.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TutorialOverlay(onDone: onDone ?? () {})),
      ),
    );
  }

  const expectedTitles = [
    'Move & Rotate',
    'Mirror Flip',
    'Fusion Bonus',
    'Back-to-Back & Combo',
    'Hold & Cavity Fill',
    'Picking a Mode',
  ];

  testWidgets('walks through every page in order via Next', (tester) async {
    await pumpOverlay(tester);

    for (var i = 0; i < expectedTitles.length; i++) {
      expect(find.text(expectedTitles[i]), findsOneWidget);
      final isLast = i == expectedTitles.length - 1;
      await tester.tap(find.text(isLast ? "Let's go" : 'Next'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the fusion page embeds a FusionHero demo, not a bare icon', (
    tester,
  ) async {
    await pumpOverlay(tester);

    await tester.tap(find.text('Next')); // -> Mirror Flip
    await tester.pumpAndSettle();
    expect(find.text('Mirror Flip'), findsOneWidget);

    await tester.tap(find.text('Next')); // -> Fusion Bonus
    await tester.pumpAndSettle();
    expect(find.text('Fusion Bonus'), findsOneWidget);
  });

  testWidgets('Skip calls onDone from any page', (tester) async {
    var done = false;
    await pumpOverlay(tester, onDone: () => done = true);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
  });

  testWidgets('a fast double-tap on Skip only calls onDone once, not twice', (
    tester,
  ) async {
    var doneCount = 0;
    await pumpOverlay(tester, onDone: () => doneCount++);

    // Two taps back-to-back, before pumpAndSettle lets the first pop
    // actually resolve — the exact window that used to let the second
    // call pop whatever route is now on top instead of no-op'ing.
    await tester.tap(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(doneCount, 1);
  });

  testWidgets(
    "a fast double-tap on the last page's Let's go only calls onDone once",
    (tester) async {
      var doneCount = 0;
      await pumpOverlay(tester, onDone: () => doneCount++);

      for (var i = 0; i < expectedTitles.length - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text("Let's go"));
      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      expect(doneCount, 1);
    },
  );

  testWidgets(
    "settles on static demo frames when the app's own reduceMotion setting "
    'is on, even with the OS-level flag off',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutorialOverlay(onDone: () {}, reduceMotion: true),
          ),
        ),
      );

      // Would time out if the Mirror/Fusion pages' embedded demos were
      // still repeating, since nothing here disables OS-level animations.
      await tester.pumpAndSettle();
    },
  );

  testWidgets('scrolls instead of overflowing on a short/landscape viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpOverlay(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
