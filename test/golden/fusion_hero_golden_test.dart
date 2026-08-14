import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/fusion_hero.dart';

/// Golden-image snapshots purely for visual inspection (no browser/screenshot
/// tool is available in this environment) — not meant as a strict pixel-diff
/// regression gate. `matchesGoldenFile` only rasterizes the finder's own
/// bounds, not an ancestor's background, so the dark backdrop has to be
/// inside the captured widget itself (a Key'd, sized, colored Container) —
/// capturing FusionHero directly would show its transparent canvas over a
/// flattened-to-white PNG background instead.
void main() {
  const backdropKey = Key('backdrop');

  Widget harness(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Container(
          key: backdropKey,
          width: 160,
          height: 160,
          color: const Color(0xFF0F131D),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ),
  );

  testWidgets('resting fused frame (reduceMotion)', (tester) async {
    await tester.pumpWidget(
      harness(
        const FusionHero(
          colorA: Colors.cyanAccent,
          colorB: Colors.pinkAccent,
          reduceMotion: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(backdropKey),
      matchesGoldenFile('goldens/fusion_hero_resting.png'),
    );
  });

  testWidgets('mid-slide frame (halves approaching)', (tester) async {
    await tester.pumpWidget(
      harness(
        const FusionHero(colorA: Colors.cyanAccent, colorB: Colors.pinkAccent),
      ),
    );
    // Loop is 3200ms; the slide phase is roughly [0.15, 0.45) — 900ms lands
    // in the middle of it (~t=0.28).
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byKey(backdropKey),
      matchesGoldenFile('goldens/fusion_hero_mid_slide.png'),
    );
  });

  testWidgets('fusion flash frame (halves just met)', (tester) async {
    await tester.pumpWidget(
      harness(
        const FusionHero(colorA: Colors.cyanAccent, colorB: Colors.pinkAccent),
      ),
    );
    // t=0.47 lands just past the 0.45 fuse boundary, near-peak white flash.
    await tester.pump(const Duration(milliseconds: 1504));
    await expectLater(
      find.byKey(backdropKey),
      matchesGoldenFile('goldens/fusion_hero_flash.png'),
    );
  });
}
