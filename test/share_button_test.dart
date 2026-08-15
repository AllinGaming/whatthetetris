import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/game_animations.dart';
import 'package:whatthetetris/models/board.dart';
import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/models/piece.dart';
import 'package:whatthetetris/models/theme_palette.dart';
import 'package:whatthetetris/ui/game_side_panel.dart';
import 'package:whatthetetris/ui/mobile_stats_bar.dart';

void main() {
  testWidgets(
    'GameSidePanel shows a Share button once the run is over, and it fires',
    (WidgetTester tester) async {
      var shared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameSidePanel(
              width: 260,
              mode: GameMode.classic,
              state: GameState.over,
              score: 4200,
              lines: 12,
              level: 2,
              bestScore: 4200,
              bestLevel: 2,
              cavityCharges: 1,
              speedBoost: 0,
              upcoming: const [],
              upcomingColors: const [],
              nextMirrored: false,
              held: null,
              heldColor: null,
              theme: ThemePalette.neon,
              colorMode: PieceColorMode.duo,
              canHold: true,
              canSpeedUp: false,
              toasts: const {},
              onRemoveToast: (_) {},
              onPauseOrPlay: () {},
              onRestart: () {},
              onMoveLeft: () {},
              onMoveRight: () {},
              onSoftDrop: () {},
              onHardDrop: () {},
              onRotateLeft: () {},
              onRotateRight: () {},
              onMirror: () {},
              onHold: () {},
              onSpeedUp: () {},
              onFillCavities: () {},
              onMenu: () {},
              onShare: () => shared = true,
            ),
          ),
        ),
      );

      expect(find.text('Share'), findsOneWidget);
      await tester.ensureVisible(find.text('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      expect(shared, isTrue);
    },
  );

  testWidgets(
    'MobileStatsBar swaps the next-piece preview for a share icon on game over',
    (WidgetTester tester) async {
      var shared = false;
      final anim = GameAnimations(vsync: const TestVSync());
      addTearDown(anim.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileStatsBar(
              state: GameState.over,
              score: 4200,
              lines: 12,
              level: 2,
              upcoming: const [],
              upcomingColor: null,
              nextMirrored: false,
              theme: ThemePalette.neon,
              colorMode: PieceColorMode.duo,
              anim: anim,
              onPauseOrPlay: () {},
              onMenu: () {},
              onShare: () => shared = true,
            ),
          ),
        ),
      );

      final shareButton = find.byTooltip('Share result');
      expect(shareButton, findsOneWidget);
      await tester.tap(shareButton);
      expect(shared, isTrue);
    },
  );

  testWidgets(
    'MobileStatsBar shows the next-piece preview, not the share icon, mid-game',
    (WidgetTester tester) async {
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
              nextMirrored: false,
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

      expect(find.byTooltip('Share result'), findsNothing);
    },
  );
}
