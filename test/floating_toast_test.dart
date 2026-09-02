import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/floating_toast.dart';

void main() {
  testWidgets('custom co-op toast remains readable for its full hold', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: FloatingToast(
                data: const ToastData(
                  '3x TEAM COMBO!',
                  Colors.cyan,
                  big: true,
                  subtitle: 'TEAM +975 · FUSION +50 · COMBO +100',
                  duration: Duration(milliseconds: 1800),
                  backdrop: true,
                ),
                onDone: () => completed = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('3x TEAM COMBO!'), findsOneWidget);
    expect(find.textContaining('FUSION +50'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('floating-toast-backdrop')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1300));
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 550));
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
