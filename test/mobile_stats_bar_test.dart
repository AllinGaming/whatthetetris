import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/game_animations.dart';
import 'package:whatthetetris/models/board.dart';
import 'package:whatthetetris/models/piece.dart';
import 'package:whatthetetris/models/theme_palette.dart';
import 'package:whatthetetris/ui/mobile_stats_bar.dart';

void main() {
  Color topBorderColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(MobileStatsBar),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    return decoration.border!.top.color;
  }

  testWidgets('combo heat tints the top border toward red as it climbs', (
    tester,
  ) async {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileStatsBar(
            state: GameState.playing,
            score: 0,
            lines: 0,
            level: 1,
            upcoming: const [],
            upcomingColor: null,
            theme: ThemePalette.neon,
            colorMode: PieceColorMode.duo,
            anim: anim,
            onPauseOrPlay: () {},
            onMenu: () {},
            onShare: () {},
          ),
        ),
      ),
    );

    final baseline = topBorderColor(tester);

    anim.setComboHeat(1.0);
    await tester.pump();
    final withCombo = topBorderColor(tester);
    anim.resetForNewRun(); // stop the repeating pulse before teardown

    expect(withCombo, isNot(baseline));
  });

  testWidgets('danger takes priority over combo heat for the same border', (
    tester,
  ) async {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileStatsBar(
            state: GameState.playing,
            score: 0,
            lines: 0,
            level: 1,
            upcoming: const [],
            upcomingColor: null,
            theme: ThemePalette.neon,
            colorMode: PieceColorMode.duo,
            anim: anim,
            onPauseOrPlay: () {},
            onMenu: () {},
            onShare: () {},
          ),
        ),
      ),
    );

    anim.setComboHeat(1.0);
    anim.setDanger(true);
    await tester.pump();

    final color = topBorderColor(tester);
    anim.resetForNewRun(); // stop the repeating pulses before teardown

    expect(color.r, closeTo(Colors.redAccent.r, 0.01));
    expect(color.g, closeTo(Colors.redAccent.g, 0.01));
    expect(color.b, closeTo(Colors.redAccent.b, 0.01));
  });
}
