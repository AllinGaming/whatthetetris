import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/tutorial_level_screen.dart';

/// Pushes the tutorial level on top of a placeholder screen — Skip calls
/// `Navigator.maybePop`, which only actually pops when there's something to
/// pop back to, matching how every real caller pushes this screen.
Future<void> _pumpPushed(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TutorialLevelScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _advance(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 750));
}

void main() {
  testWidgets('starts on the Move & Rotate step', (tester) async {
    await _pumpPushed(tester);

    expect(
      find.textContaining('Move it'),
      findsOneWidget,
      reason: 'first step should ask the player to move/rotate the piece',
    );
  });

  testWidgets('walking through every step reaches the finish screen', (
    tester,
  ) async {
    await _pumpPushed(tester);

    // Step 1: Move & Rotate -> Hard Drop. Completion doesn't require the
    // move/rotate to have actually happened first (see _onLocked), so a
    // bare hard drop is enough to reliably advance in a test.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await _advance(tester);

    expect(find.textContaining("won't fuse"), findsOneWidget);

    // Step 2: Mirror, then drop it -- must be mirrored at lock time.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await _advance(tester);

    expect(find.textContaining('Mirror it'), findsOneWidget);

    // Step 3: Fusion -- mirror, then drop anywhere on the pre-placed row.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await _advance(tester);

    expect(find.textContaining('hold this piece'), findsOneWidget);

    // Step 4: Hold.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    await _advance(tester);

    expect(find.textContaining('fill that stray gap'), findsOneWidget);

    // Step 5: Cavity Fill.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pump();
    await _advance(tester);

    expect(find.text("You're ready — go play!"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Finish'), findsOneWidget);
  });

  testWidgets('Skip exits the level immediately from any step', (
    tester,
  ) async {
    await _pumpPushed(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(TutorialLevelScreen), findsNothing);
  });

  testWidgets('builds without exceptions at a small mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPushed(tester);

    expect(tester.takeException(), isNull);
  });
}
