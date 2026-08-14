import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/services/settings_service.dart';
import 'package:whatthetetris/ui/widgets/touch_dpad.dart';

void main() {
  Widget buildPad(TouchHandedness handedness) {
    return MaterialApp(
      home: Scaffold(
        body: TouchDpad(
          enabled: true,
          onMoveLeft: () {},
          onMoveRight: () {},
          onSoftDrop: () {},
          onRotateLeft: () {},
          onRotateRight: () {},
          onMirror: () {},
          onHold: () {},
          canHold: true,
          onHardDrop: () {},
          onFillCavities: () {},
          cavityCharges: 1,
          onSpeedUp: () {},
          speedBoost: 0,
          handedness: handedness,
        ),
      ),
    );
  }

  // The pad is a two-cluster layout (move track + action cluster incl. the
  // hard-drop hero button) rather than a single row, so handedness is
  // exercised by checking which side each cluster ends up on, not by
  // reading a shared Row's alignment.
  double xOf(WidgetTester tester, String tooltip) =>
      tester.getTopLeft(find.byTooltip(tooltip)).dx;

  testWidgets('balanced handedness puts the move track on the left', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPad(TouchHandedness.balanced));
    expect(
      xOf(tester, 'Move left'),
      lessThan(xOf(tester, 'Hard drop')),
    );
  });

  testWidgets('left-handed keeps the move track on the left', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPad(TouchHandedness.left));
    expect(
      xOf(tester, 'Move left'),
      lessThan(xOf(tester, 'Hard drop')),
    );
  });

  testWidgets('right-handed swaps the move track to the right', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPad(TouchHandedness.right));
    expect(
      xOf(tester, 'Move left'),
      greaterThan(xOf(tester, 'Hard drop')),
    );
  });
}
