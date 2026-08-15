import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/game_animations.dart';
import 'package:whatthetetris/models/board.dart';
import 'package:whatthetetris/models/piece.dart';
import 'package:whatthetetris/models/theme_palette.dart';
import 'package:whatthetetris/ui/mobile_stats_bar.dart';

/// Golden-image snapshots of the mobile HUD's danger/combo border coloring
/// — added this session but never actually seen rendered, since no
/// browser/screenshot tool is available in this environment.
void main() {
  Widget harness(Widget child) => MaterialApp(
    home: Scaffold(backgroundColor: const Color(0xFF0F131D), body: child),
  );

  testWidgets('baseline (no danger, no combo)', (tester) async {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);

    await tester.pumpWidget(
      harness(
        MobileStatsBar(
          state: GameState.playing,
          score: 12400,
          lines: 34,
          level: 4,
          upcoming: const [],
          upcomingColor: null,
          nextMirrored: false,
          theme: ThemePalette.neon,
          colorMode: PieceColorMode.duo,
          anim: anim,
          onPauseOrPlay: () {},
          onMenu: () {},
          onShare: () {},
        ),
      ),
    );
    await expectLater(
      find.byType(MobileStatsBar),
      matchesGoldenFile('goldens/mobile_stats_bar_baseline.png'),
    );
  });

  testWidgets('max combo heat glow', (tester) async {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);
    anim.setComboHeat(1.0);
    anim.comboPulse.value = 1.0; // peak of the pulse

    await tester.pumpWidget(
      harness(
        MobileStatsBar(
          state: GameState.playing,
          score: 12400,
          lines: 34,
          level: 4,
          upcoming: const [],
          upcomingColor: null,
          nextMirrored: false,
          theme: ThemePalette.neon,
          colorMode: PieceColorMode.duo,
          anim: anim,
          onPauseOrPlay: () {},
          onMenu: () {},
          onShare: () {},
        ),
      ),
    );
    anim.resetForNewRun(); // stop the repeating pulse before teardown
    await expectLater(
      find.byType(MobileStatsBar),
      matchesGoldenFile('goldens/mobile_stats_bar_combo.png'),
    );
  });

  testWidgets('danger border', (tester) async {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);
    anim.setDanger(true);
    anim.danger.value = 1.0; // peak of the pulse

    await tester.pumpWidget(
      harness(
        MobileStatsBar(
          state: GameState.playing,
          score: 12400,
          lines: 34,
          level: 4,
          upcoming: const [],
          upcomingColor: null,
          nextMirrored: false,
          theme: ThemePalette.neon,
          colorMode: PieceColorMode.duo,
          anim: anim,
          onPauseOrPlay: () {},
          onMenu: () {},
          onShare: () {},
        ),
      ),
    );
    anim.resetForNewRun();
    await expectLater(
      find.byType(MobileStatsBar),
      matchesGoldenFile('goldens/mobile_stats_bar_danger.png'),
    );
  });
}
