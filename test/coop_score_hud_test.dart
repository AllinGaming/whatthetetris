import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/coop_score_hud.dart';

void main() {
  Widget wrap(Widget child, {double width = 320}) => MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  testWidgets('co-op HUD gives the shared score strongest visibility', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CoopScoreHud(
          connected: true,
          score: 4250,
          lines: 14,
          combo: 3,
          backToBack: 2,
          redLines: 8,
          blueLines: 6,
          bestScore: 12800,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEAM SCORE'), findsOneWidget);
    expect(find.text('4,250'), findsOneWidget);
    expect(find.text('BEST 12,800'), findsOneWidget);
    expect(find.text('TEAM LINES'), findsOneWidget);
    expect(find.text('RED 8'), findsOneWidget);
    expect(find.text('BLUE 6'), findsOneWidget);
    expect(find.text('3x COMBO · B2B 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('co-op puzzle HUD names the remaining-row objective', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CoopScoreHud(
          connected: false,
          score: 990,
          lines: 2,
          combo: 0,
          backToBack: 0,
          redLines: 1,
          blueLines: 1,
          bestScore: 1200,
          puzzleRowsRemaining: 4,
          puzzleSpeedBonusPreview: 4940,
        ),
        width: 600,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RECONNECTING'), findsOneWidget);
    expect(find.text('ROWS TO GO'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('SPEED +4,940'), findsOneWidget);
    expect(find.text('RED CLEARS 1'), findsOneWidget);
    expect(find.text('BLUE CLEARS 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('score formatting keeps large team scores scannable', () {
    expect(formatCoopScore(0), '0');
    expect(formatCoopScore(999), '999');
    expect(formatCoopScore(1234567), '1,234,567');
  });
}
