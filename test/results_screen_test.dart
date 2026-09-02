import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/models/achievement.dart';
import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/ui/widgets/results_screen.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('shows the score, mode, and run stats', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ResultsScreen(
          mode: GameMode.arcade,
          score: 4200,
          level: 5,
          lines: 42,
          isNewBest: false,
          durationMs: 90000,
          fusions: 3,
          fourLineClears: 1,
          mirrorUses: 6,
          cavityFills: 2,
          newlyUnlocked: const [],
          onPlayAgain: () {},
          onShare: () {},
          onMenu: () {},
        ),
      ),
    );

    expect(find.text('Run Complete'), findsOneWidget);
    expect(find.text('Arcade'), findsOneWidget);
    expect(find.text('4200'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget); // duration
    expect(find.textContaining('ACHIEVEMENT'), findsNothing);
  });

  testWidgets('a new best shows the celebratory heading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ResultsScreen(
          mode: GameMode.classic,
          score: 100,
          level: 1,
          lines: 1,
          isNewBest: true,
          durationMs: 1000,
          fusions: 0,
          fourLineClears: 0,
          mirrorUses: 0,
          cavityFills: 0,
          newlyUnlocked: const [],
          onPlayAgain: () {},
          onShare: () {},
          onMenu: () {},
        ),
      ),
    );

    expect(find.text('New Best!'), findsOneWidget);
  });

  testWidgets(
    'newly unlocked achievements are listed with title and description',
    (WidgetTester tester) async {
      final achievement = Achievement.all.firstWhere(
        (a) => a.id == 'first_clear',
      );

      await tester.pumpWidget(
        wrap(
          ResultsScreen(
            mode: GameMode.classic,
            score: 100,
            level: 1,
            lines: 1,
            isNewBest: false,
            durationMs: 1000,
            fusions: 0,
            fourLineClears: 0,
            mirrorUses: 0,
            cavityFills: 0,
            newlyUnlocked: [achievement],
            onPlayAgain: () {},
            onShare: () {},
            onMenu: () {},
          ),
        ),
      );

      expect(find.textContaining('ACHIEVEMENT'), findsOneWidget);
      expect(find.text(achievement.title), findsOneWidget);
      expect(find.text(achievement.description), findsOneWidget);
    },
  );

  testWidgets('Play Again, Share, and Menu all fire their callbacks', (
    WidgetTester tester,
  ) async {
    var playedAgain = false;
    var shared = false;
    var wentToMenu = false;

    await tester.pumpWidget(
      wrap(
        ResultsScreen(
          mode: GameMode.classic,
          score: 100,
          level: 1,
          lines: 1,
          isNewBest: false,
          durationMs: 1000,
          fusions: 0,
          fourLineClears: 0,
          mirrorUses: 0,
          cavityFills: 0,
          newlyUnlocked: const [],
          onPlayAgain: () => playedAgain = true,
          onShare: () => shared = true,
          onMenu: () => wentToMenu = true,
        ),
      ),
    );

    await tester.tap(find.text('Play Again'));
    await tester.tap(find.text('Share'));
    await tester.tap(find.text('Menu'));

    expect(playedAgain, isTrue);
    expect(shared, isTrue);
    expect(wentToMenu, isTrue);
  });

  testWidgets('Daily Challenge offers Play Again for repeat attempts', (
    WidgetTester tester,
  ) async {
    var playedAgain = false;
    var shared = false;

    await tester.pumpWidget(
      wrap(
        ResultsScreen(
          mode: GameMode.daily,
          score: 100,
          level: 1,
          lines: 1,
          isNewBest: false,
          challengeCleared: true,
          speedBonus: 4990,
          durationMs: 1000,
          fusions: 0,
          fourLineClears: 0,
          mirrorUses: 0,
          cavityFills: 0,
          newlyUnlocked: const [],
          onPlayAgain: () => playedAgain = true,
          onShare: () => shared = true,
          onMenu: () {},
        ),
      ),
    );

    await tester.tap(find.text('Play Again'));
    await tester.tap(find.text('Share'));
    expect(find.text('Speed bonus'), findsOneWidget);
    expect(find.text('+4990'), findsOneWidget);
    expect(playedAgain, isTrue);
    expect(shared, isTrue);
  });
}
