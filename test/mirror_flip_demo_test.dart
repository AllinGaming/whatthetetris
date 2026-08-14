import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/mirror_flip_demo.dart';

void main() {
  testWidgets('renders and settles on a static frame under reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const MaterialApp(home: MirrorFlipDemo(color: Colors.orangeAccent)),
    );

    expect(find.byType(MirrorFlipDemo), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('sits idle until tapped, rather than auto-looping', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MirrorFlipDemo(color: Colors.orangeAccent)),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason:
          'MirrorFlipDemo is tap-to-flip now — it should never animate on '
          'its own.',
    );
    expect(find.text('Tap to flip'), findsOneWidget);
  });

  testWidgets('tapping plays the flip once, then settles again', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MirrorFlipDemo(color: Colors.orangeAccent)),
    );

    await tester.tap(find.text('Tap to flip'));
    await tester.pump();
    expect(
      tester.binding.hasScheduledFrame,
      isTrue,
      reason: 'the one-shot flip should be animating right after the tap',
    );

    await tester.pumpAndSettle();
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'it should settle once the flip finishes, not keep looping',
    );

    // Tapping again flips back — should also complete cleanly.
    await tester.tap(find.text('Tap to flip'));
    await tester.pumpAndSettle();
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
          home: MirrorFlipDemo(color: Colors.orangeAccent, reduceMotion: true),
        ),
      );

      await tester.pumpAndSettle();

      // A tap should still toggle the state instantly (no animation to
      // watch, but the mechanic itself stays interactive).
      await tester.tap(find.text('Tap to flip'));
      await tester.pumpAndSettle();
    },
  );
}
