import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/game/board_painter.dart';
import 'package:whatthetetris/game/game_screen.dart';
import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/services/audio_service.dart';
import 'package:whatthetetris/services/daily_challenge_service.dart';
import 'package:whatthetetris/services/high_score_service.dart';
import 'package:whatthetetris/services/live_services.dart';
import 'package:whatthetetris/services/settings_service.dart';
import 'package:whatthetetris/services/stats_service.dart';
import 'package:whatthetetris/services/theme_service.dart';
import 'package:whatthetetris/ui/widgets/touch_dpad.dart';

Future<void> _pumpGame(
  WidgetTester tester, {
  required Size size,
  bool gestures = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({
    'settings_seen_tutorial': true,
    if (gestures) 'settings_touch_control_scheme': 'gestures',
  });
  final highScores = await HighScoreService.create();
  final audio = await AudioService.create();
  final settings = await SettingsService.create();
  final theme = await ThemeService.create();
  final stats = await StatsService.create();
  final dailyChallenge = await DailyChallengeService.create();
  final live = await LiveServices.create();

  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        mode: GameMode.classic,
        highScores: highScores,
        audio: audio,
        settings: settings,
        theme: theme,
        stats: stats,
        dailyChallenge: dailyChallenge,
        live: live,
      ),
    ),
  );
  // Classic has no ready countdown, so gravity starts immediately -- enough
  // time for setup to settle, nowhere near a full gravity tick at level 1.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Finder _boardFinder() => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is BoardPainter,
);

BoardPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_boardFinder()).painter as BoardPainter;

void main() {
  testWidgets('gestures scheme hides the TouchDpad on a narrow viewport', (
    tester,
  ) async {
    await _pumpGame(tester, size: const Size(390, 844), gestures: true);

    expect(find.byType(TouchDpad), findsNothing);
  });

  testWidgets('buttons scheme (default) still shows the TouchDpad', (
    tester,
  ) async {
    await _pumpGame(tester, size: const Size(390, 844));

    expect(find.byType(TouchDpad), findsOneWidget);
  });

  testWidgets('tapping the board mirrors instead of rotating under gestures', (
    tester,
  ) async {
    await _pumpGame(tester, size: const Size(1200, 900), gestures: true);

    expect(_painter(tester).active!.mirrored, isFalse);

    await tester.tapAt(tester.getCenter(_boardFinder()));
    // onDoubleTap is also wired under gestures, so Flutter must wait out
    // the double-tap disambiguation window before a single tap actually
    // fires -- and before that recognizer's own internal timer is safe to
    // leave pending at test teardown.
    await tester.pump(const Duration(milliseconds: 400));

    expect(_painter(tester).active!.mirrored, isTrue);
  });

  testWidgets('double-tapping the board hard-drops under gestures', (
    tester,
  ) async {
    await _pumpGame(tester, size: const Size(1200, 900), gestures: true);

    final revisionBefore = _painter(tester).boardRevision;
    final center = tester.getCenter(_boardFinder());

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _painter(tester).boardRevision,
      greaterThan(revisionBefore),
      reason: 'double-tap should hard-drop and lock the piece',
    );
  });

  testWidgets('swiping up on the board rotates under gestures', (tester) async {
    await _pumpGame(tester, size: const Size(1200, 900), gestures: true);

    final rotationBefore = _painter(tester).active!.rotation;

    await tester.fling(_boardFinder(), const Offset(0, -80), 3000);
    await tester.pump(const Duration(milliseconds: 400));

    expect(_painter(tester).active!.rotation, isNot(rotationBefore));
  });

  testWidgets(
    'gestures scheme on mobile adds a menu button and cavity badge on the '
    'board, since the D-pad that normally carries them is hidden',
    (tester) async {
      await _pumpGame(tester, size: const Size(390, 844), gestures: true);

      // MobileStatsBar already has its own menu button below the board --
      // gestures scheme adds a second one on the board itself.
      expect(find.byTooltip('Menu'), findsNWidgets(2));
      expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
    },
  );

  testWidgets(
    'buttons scheme on mobile does not add the extra board HUD -- the '
    'D-pad already shows the cavity count',
    (tester) async {
      await _pumpGame(tester, size: const Size(390, 844));

      expect(find.byTooltip('Menu'), findsOneWidget);
    },
  );
}
