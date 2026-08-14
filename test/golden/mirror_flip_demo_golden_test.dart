import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/mirror_flip_demo.dart';

/// Golden-image snapshots purely for visual inspection (no browser/screenshot
/// tool is available in this environment) — not meant as a strict pixel-diff
/// regression gate. `matchesGoldenFile` only rasterizes the finder's own
/// bounds, not an ancestor's background, so the dark backdrop has to be
/// inside the captured widget itself (a Key'd Container), not an ancestor.
void main() {
  const backdropKey = Key('backdrop');

  Widget harness(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Container(
          key: backdropKey,
          width: 180,
          height: 140,
          color: const Color(0xFF0F131D),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ),
  );

  testWidgets('resting "before" frame (reduceMotion)', (tester) async {
    await tester.pumpWidget(
      harness(
        const MirrorFlipDemo(color: Colors.orangeAccent, reduceMotion: true),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(backdropKey),
      matchesGoldenFile('goldens/mirror_flip_before.png'),
    );
  });

  testWidgets('mid-flip frame (card turning edge-on)', (tester) async {
    await tester.pumpWidget(
      harness(const MirrorFlipDemo(color: Colors.orangeAccent)),
    );
    // Tap-to-flip is a 320ms one-shot now (not an auto-loop) — 160ms is its
    // midpoint (edge-on). The zero-duration pump first processes the tap
    // itself and starts the ticker (elapsed=0 baseline); only the *next*
    // pump actually advances it — a single pump(160ms) right after tap()
    // would report 0ms elapsed, not 160ms, and capture the untouched frame.
    await tester.tap(find.text('Tap to flip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    await expectLater(
      find.byKey(backdropKey),
      matchesGoldenFile('goldens/mirror_flip_mid_turn.png'),
    );
  });

  testWidgets('resting "after" frame (mirrored)', (tester) async {
    await tester.pumpWidget(
      harness(const MirrorFlipDemo(color: Colors.orangeAccent)),
    );
    await tester.tap(find.text('Tap to flip'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(backdropKey),
      matchesGoldenFile('goldens/mirror_flip_after.png'),
    );
  });
}
