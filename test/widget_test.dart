// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/game/board_painter.dart';
import 'package:whatthetetris/main.dart';
import 'package:whatthetetris/services/high_score_service.dart';
import 'package:whatthetetris/ui/game_side_panel.dart';
import 'package:whatthetetris/ui/mobile_stats_bar.dart';
import 'package:whatthetetris/ui/widgets/touch_dpad.dart';

void main() {
  testWidgets('start screen leads into a playable game', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final highScores = await HighScoreService.create();
    await tester.pumpWidget(HalfBlockPyramidApp(highScores: highScores));

    expect(find.text('What The Tetris'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Arcade'), findsOneWidget);

    await tester.tap(find.text('Arcade'));
    await tester.pumpAndSettle();

    expect(find.byType(KeyboardListener), findsOneWidget);
  });

  testWidgets('Classic mode keeps the cavity filler but hides speed-boost', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final highScores = await HighScoreService.create();
    await tester.pumpWidget(HalfBlockPyramidApp(highScores: highScores));

    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fill Cavities'), findsOneWidget);
    expect(find.textContaining('Speed Up'), findsNothing);
    expect(find.text('Mirror (M)'), findsOneWidget);
  });

  testWidgets('Arcade mode keeps the cavity-filler and speed-boost controls', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final highScores = await HighScoreService.create();
    await tester.pumpWidget(HalfBlockPyramidApp(highScores: highScores));

    await tester.tap(find.text('Arcade'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fill Cavities'), findsOneWidget);
    expect(find.textContaining('Speed Up'), findsOneWidget);
  });

  testWidgets('a wide window gets the desktop side panel, not the touch pad', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final highScores = await HighScoreService.create();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(HalfBlockPyramidApp(highScores: highScores));
    await tester.tap(find.text('Arcade'));
    await tester.pumpAndSettle();

    expect(find.byType(GameSidePanel), findsOneWidget);
    expect(find.byType(TouchDpad), findsNothing);
    expect(find.byType(MobileStatsBar), findsNothing);
  });

  testWidgets('a narrow window gets the mobile touch pad, not the side panel', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final highScores = await HighScoreService.create();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(HalfBlockPyramidApp(highScores: highScores));
    await tester.tap(find.text('Arcade'));
    await tester.pumpAndSettle();

    expect(find.byType(TouchDpad), findsOneWidget);
    expect(find.byType(MobileStatsBar), findsOneWidget);
    expect(find.byType(GameSidePanel), findsNothing);
  });

  testWidgets('the board actually renders at a real size, not collapsed to zero', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final highScores = await HighScoreService.create();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(HalfBlockPyramidApp(highScores: highScores));
    await tester.tap(find.text('Arcade'));
    await tester.pumpAndSettle();

    final board = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is BoardPainter,
    );
    expect(board, findsOneWidget);
    // A collapsed/near-zero board (e.g. from a stray Stack loosening its
    // constraints) is the exact bug this guards against.
    final size = tester.getSize(board);
    expect(size.width, greaterThan(200));
    expect(size.height, greaterThan(200));
  });
}
