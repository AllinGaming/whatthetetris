import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/score_trend_sparkline.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('empty history shows a placeholder, not a broken chart', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ScoreTrendSparkline(values: [], accent: Colors.cyan)),
    );

    expect(find.textContaining('Play a few runs'), findsOneWidget);
  });

  testWidgets('a single point renders without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ScoreTrendSparkline(values: [0.5], accent: Colors.cyan)),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Last run: 50%'), findsOneWidget);
  });

  testWidgets('a rising trend is labeled and renders without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ScoreTrendSparkline(values: [0.2, 0.4, 0.9], accent: Colors.cyan),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Last run: 90%'), findsOneWidget);
    expect(find.textContaining('trending up'), findsOneWidget);
  });

  testWidgets('a falling trend is labeled correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ScoreTrendSparkline(values: [0.9, 0.4, 0.2], accent: Colors.cyan),
      ),
    );

    expect(find.textContaining('trending down'), findsOneWidget);
  });
}
