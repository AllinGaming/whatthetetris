import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/fusion_hero.dart';

void main() {
  testWidgets('renders and settles on a static frame under reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        home: FusionHero(colorA: Colors.cyan, colorB: Colors.pinkAccent),
      ),
    );

    expect(find.byType(FusionHero), findsOneWidget);
    // Would time out if the controller were still repeating.
    await tester.pumpAndSettle();
  });

  testWidgets('loops indefinitely when animations are enabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FusionHero(colorA: Colors.cyan, colorB: Colors.pinkAccent),
      ),
    );

    await tester.pump(const Duration(seconds: 5));
    // Still ticking well past one 3.2s loop — proves it repeats rather than
    // running once and stopping.
    expect(
      tester.binding.hasScheduledFrame,
      isTrue,
      reason: 'FusionHero should still be animating past one full loop',
    );
  });

  testWidgets(
    "settles on a static frame when the app's own reduceMotion setting is "
    'on, even with the OS-level flag off',
    (tester) async {
      // No accessibilityFeaturesTestValue set here — this is specifically
      // the in-app Settings > Accessibility > "Reduce motion" toggle, not
      // the OS signal the other test covers.
      await tester.pumpWidget(
        const MaterialApp(
          home: FusionHero(
            colorA: Colors.cyan,
            colorB: Colors.pinkAccent,
            reduceMotion: true,
          ),
        ),
      );

      // Would time out if the controller were still repeating.
      await tester.pumpAndSettle();
    },
  );
}
