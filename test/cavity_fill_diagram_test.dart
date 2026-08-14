import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/cavity_fill_diagram.dart';

void main() {
  testWidgets('renders a before/after pair with an arrow between them', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CavityFillDiagram(color: Colors.lightGreenAccent),
      ),
    );

    expect(find.byType(CavityFillDiagram), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}
