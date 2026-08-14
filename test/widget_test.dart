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
import 'package:whatthetetris/game/game_screen.dart';
import 'package:whatthetetris/main.dart';
import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/models/piece.dart';
import 'package:whatthetetris/services/audio_service.dart';
import 'package:whatthetetris/services/daily_challenge_service.dart';
import 'package:whatthetetris/services/high_score_service.dart';
import 'package:whatthetetris/services/live_services.dart';
import 'package:whatthetetris/services/settings_service.dart';
import 'package:whatthetetris/services/stats_service.dart';
import 'package:whatthetetris/services/theme_service.dart';
import 'package:whatthetetris/ui/game_side_panel.dart';
import 'package:whatthetetris/ui/mobile_stats_bar.dart';
import 'package:whatthetetris/ui/settings_screen.dart';
import 'package:whatthetetris/ui/start_screen.dart';
import 'package:whatthetetris/ui/widgets/pause_menu.dart';
import 'package:whatthetetris/ui/widgets/touch_dpad.dart';
import 'package:whatthetetris/ui/widgets/tutorial_overlay.dart';

/// Defaults used by every test that isn't specifically exercising the
/// first-run tutorial overlay, so that dialog doesn't block taps on the
/// real in-game controls underneath it.
const _tutorialAlreadySeen = {'settings_seen_tutorial': true};

/// The start screen's FusionHero loops forever via AnimationController.repeat,
/// which is correct in production but leaves pumpAndSettle waiting for a
/// frame that never stops being scheduled. Flagging OS-level "reduce motion"
/// makes FusionHero settle on a static frame instead, matching how a real
/// accessibility setting would behave — no change to any other test's
/// reduceMotion-dependent behavior, which reads a separate in-app setting.
void _disableTestAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pumpApp(WidgetTester tester) async {
  _disableTestAnimations(tester);
  SharedPreferences.setMockInitialValues(_tutorialAlreadySeen);
  final highScores = await HighScoreService.create();
  final audio = await AudioService.create();
  final settings = await SettingsService.create();
  final theme = await ThemeService.create();
  final stats = await StatsService.create();
  final dailyChallenge = await DailyChallengeService.create();
  final live = await LiveServices.create();
  await tester.pumpWidget(
    HalfBlockPyramidApp(
      highScores: highScores,
      audio: audio,
      settings: settings,
      theme: theme,
      stats: stats,
      dailyChallenge: dailyChallenge,
      live: live,
    ),
  );
}

/// The mode roster no longer fits the default 800x600 test viewport in one
/// screen, so tapping a mode card needs to scroll it into view first.
Future<void> _tapMode(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Arcade/Sprint/Zen were trimmed from the mode-select roster but are still
/// fully playable in code — this pumps a [GameScreen] for one directly,
/// bypassing start-screen navigation, for tests that exercise that mode's
/// own mechanics rather than the mode-select UI.
Future<void> _pumpGameScreenDirect(
  WidgetTester tester,
  GameMode mode, {
  bool settle = true,
}) async {
  _disableTestAnimations(tester);
  SharedPreferences.setMockInitialValues(_tutorialAlreadySeen);
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
        mode: mode,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Long enough to clear any chained async setup in GameScreen.initState,
    // nowhere near long enough for gravity to actually drop a piece — a
    // full pumpAndSettle would let fake time run into real gameplay, which
    // can leave a periodic gravity timer/animation mid-flight at teardown.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets(
    'first-ever game screen shows the tutorial, which Skip dismisses',
    (WidgetTester tester) async {
      _disableTestAnimations(tester);
      SharedPreferences.setMockInitialValues({}); // no seen-tutorial flag
      final highScores = await HighScoreService.create();
      final audio = await AudioService.create();
      final settings = await SettingsService.create();
      final theme = await ThemeService.create();
      final stats = await StatsService.create();
      final dailyChallenge = await DailyChallengeService.create();
      final live = await LiveServices.create();
      expect(settings.hasSeenTutorial, isFalse);

      await tester.pumpWidget(
        HalfBlockPyramidApp(
          highScores: highScores,
          audio: audio,
          settings: settings,
          theme: theme,
          stats: stats,
          dailyChallenge: dailyChallenge,
          live: live,
        ),
      );

      await _tapMode(tester, 'Classic');

      expect(find.text('Move & Rotate'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing); // it's a Dialog, not one

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Move & Rotate'), findsNothing);
      expect(settings.hasSeenTutorial, isTrue);

      // Controls actually work now that the modal is gone.
      final hardDrop = find.ancestor(
        of: find.text('Hard Drop'),
        matching: find.byType(ElevatedButton),
      );
      expect(tester.widget<ElevatedButton>(hardDrop).onPressed, isNotNull);
    },
  );

  testWidgets('start screen leads into a playable game', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('What The Tetris'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Chill'), findsOneWidget);
    expect(find.text('Ultra'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    // Trimmed from the visible roster per player feedback — still fully
    // playable in code (see _pumpGameScreenDirect), just not on this screen.
    expect(find.text('Arcade'), findsNothing);
    expect(find.text('Sprint'), findsNothing);
    expect(find.text('Zen'), findsNothing);

    await _tapMode(tester, 'Classic');

    expect(find.byType(KeyboardListener), findsOneWidget);
  });

  testWidgets(
    'the mode-select screen lets you pick a piece-color mode directly',
    (WidgetTester tester) async {
      _disableTestAnimations(tester);
      SharedPreferences.setMockInitialValues(_tutorialAlreadySeen);
      final highScores = await HighScoreService.create();
      final audio = await AudioService.create();
      final settings = await SettingsService.create();
      final theme = await ThemeService.create();
      final stats = await StatsService.create();
      final dailyChallenge = await DailyChallengeService.create();
      final live = await LiveServices.create();

      expect(settings.pieceColorMode, PieceColorMode.duo);

      await tester.pumpWidget(
        MaterialApp(
          home: StartScreen(
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
      await tester.pump();

      expect(find.text('Funky'), findsOneWidget);
      await tester.tap(find.text('Funky'));
      await tester.pump();

      expect(settings.pieceColorMode, PieceColorMode.colored);
    },
  );

  testWidgets('Classic mode keeps the cavity filler but hides speed-boost', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _tapMode(tester, 'Classic');

    expect(find.textContaining('Fill Cavities'), findsOneWidget);
    expect(find.textContaining('Speed +'), findsNothing);
    expect(find.text('Mirror (M)'), findsOneWidget);
  });

  testWidgets('Arcade mode keeps the cavity-filler and speed-boost controls', (
    WidgetTester tester,
  ) async {
    // Arcade is hidden from mode-select but still fully playable in code.
    await _pumpGameScreenDirect(tester, GameMode.arcade);

    expect(find.textContaining('Fill Cavities'), findsOneWidget);
    expect(find.textContaining('Speed +'), findsOneWidget);
  });

  testWidgets('Chill mode starts a playable run on its narrower board', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _tapMode(tester, 'Chill');

    expect(find.byType(KeyboardListener), findsOneWidget);
    expect(find.byType(GameSidePanel), findsOneWidget);
  });

  testWidgets('Ultra mode surfaces a countdown clock in the HUD', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _tapMode(tester, 'Ultra');

    // The clock hasn't started yet during the ready countdown (below), so
    // this reads exactly "2:00" here — match the mm:ss shape generally
    // rather than depending on that timing detail.
    expect(find.textContaining(RegExp(r'^[12]:\d\d$')), findsOneWidget);
  });

  testWidgets(
    'Ultra shows a ready countdown before the clock and gravity start',
    (WidgetTester tester) async {
      await _pumpApp(tester);

      await _tapMode(tester, 'Ultra');

      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets(
    "Classic doesn't show a ready countdown — it's not a timed mode",
    (WidgetTester tester) async {
      await _pumpApp(tester);

      await _tapMode(tester, 'Classic');

      expect(find.text('3'), findsNothing);
    },
  );

  testWidgets('Sprint mode surfaces a lines-remaining readout in the HUD', (
    WidgetTester tester,
  ) async {
    // Sprint is hidden from mode-select but still fully playable in code.
    await _pumpGameScreenDirect(tester, GameMode.sprint);

    expect(find.textContaining('lines left'), findsOneWidget);
  });

  testWidgets(
    'Daily Challenge already played today shows a recap instead of a new run',
    (WidgetTester tester) async {
      _disableTestAnimations(tester);
      SharedPreferences.setMockInitialValues({});
      final highScores = await HighScoreService.create();
      final audio = await AudioService.create();
      final settings = await SettingsService.create();
      final theme = await ThemeService.create();
      final stats = await StatsService.create();
      final dailyChallenge = await DailyChallengeService.create();
      final live = await LiveServices.create();
      await dailyChallenge.recordResult(4200);

      await tester.pumpWidget(
        HalfBlockPyramidApp(
          highScores: highScores,
          audio: audio,
          settings: settings,
          theme: theme,
          stats: stats,
          dailyChallenge: dailyChallenge,
          live: live,
        ),
      );

      await _tapMode(tester, 'Daily Challenge');

      expect(find.text("You've already played today"), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('4200'),
        ),
        findsOneWidget,
      );
      // The recap is a dialog, not a new run.
      expect(find.byType(KeyboardListener), findsNothing);
    },
  );

  testWidgets(
    'Daily Challenge starts with a pre-filled board, not an empty one',
    (WidgetTester tester) async {
      await _pumpGameScreenDirect(tester, GameMode.daily, settle: false);

      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is CustomPaint &&
                          widget.painter is BoardPainter,
                    ),
                  )
                  .painter
              as BoardPainter;

      expect(
        painter.board.any(
          (row) =>
              row.any((c) => c.full != null || c.bl != null || c.tr != null),
        ),
        isTrue,
        reason:
            "Daily's puzzle board should start roughly half-filled, "
            'not empty like every other mode.',
      );
    },
  );

  testWidgets(
    'a live streak renders on the Daily card without overflowing a narrow screen',
    (WidgetTester tester) async {
      _disableTestAnimations(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final highScores = await HighScoreService.create();
      final audio = await AudioService.create();
      final settings = await SettingsService.create();
      final theme = await ThemeService.create();
      final stats = await StatsService.create();
      final dailyChallenge = await DailyChallengeService.create();
      final live = await LiveServices.create();
      await dailyChallenge.recordResult(100); // establishes a 1-day streak

      await tester.pumpWidget(
        HalfBlockPyramidApp(
          highScores: highScores,
          audio: audio,
          settings: settings,
          theme: theme,
          stats: stats,
          dailyChallenge: dailyChallenge,
          live: live,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsWidgets); // the flame's streak count
    },
  );

  testWidgets('Stats & Achievements screen is reachable from mode select', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Stats & Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('Stats & Achievements'), findsWidgets);
    expect(find.textContaining('Games played'), findsOneWidget);
  });

  testWidgets('Settings screen offers all three cosmetic themes', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Neon'), findsOneWidget);
    expect(find.text('Colorblind-Safe'), findsOneWidget);
    expect(find.text('Sunset'), findsOneWidget);

    await tester.tap(find.text('Sunset'));
    await tester.pumpAndSettle();
  });

  testWidgets('How to Play is reachable from the start screen, any time', (
    WidgetTester tester,
  ) async {
    // _pumpApp seeds hasSeenTutorial=true (so it doesn't block other tests)
    // — this button must still work for a returning player, not just a
    // first-timer.
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('How to Play'));
    await tester.pumpAndSettle();

    expect(find.byType(TutorialOverlay), findsOneWidget);
    expect(find.text('Move & Rotate'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(TutorialOverlay), findsNothing);
  });

  testWidgets('How to Play is also reachable from Settings', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();

    expect(find.byType(TutorialOverlay), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(TutorialOverlay), findsNothing);
  });

  testWidgets('a wide window gets the desktop side panel, not the touch pad', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);
    await _tapMode(tester, 'Classic');

    expect(find.byType(GameSidePanel), findsOneWidget);
    expect(find.byType(TouchDpad), findsNothing);
    expect(find.byType(MobileStatsBar), findsNothing);
  });

  testWidgets('a narrow window gets the mobile touch pad, not the side panel', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Arcade specifically, since it's the only mode with both the
    // cavity-filler and speed-boost controls this test checks for — hidden
    // from mode-select, but still fully playable via direct construction.
    // settle: false because Arcade has no start countdown (gravity starts
    // the instant GameScreen mounts), and a full settle would let fake time
    // run into real gameplay, risking a dangling periodic timer at teardown.
    await _pumpGameScreenDirect(tester, GameMode.arcade, settle: false);

    expect(find.byType(TouchDpad), findsOneWidget);
    expect(find.byType(MobileStatsBar), findsOneWidget);
    expect(find.byType(GameSidePanel), findsNothing);

    final pad = tester.widget<TouchDpad>(find.byType(TouchDpad));
    expect(pad.onFillCavities, isNotNull);
    expect(pad.onSpeedUp, isNotNull);
    expect(pad.canHold, isTrue);
  });

  testWidgets('pausing disables gameplay buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);
    await _tapMode(tester, 'Classic');
    await tester.tap(find.text('Pause'));
    await tester.pump();

    final hardDrop = find.ancestor(
      of: find.text('Hard Drop'),
      matching: find.byType(ElevatedButton),
    );
    expect(tester.widget<ElevatedButton>(hardDrop).onPressed, isNull);
    // Both the side panel's toggle button and the new PauseMenu overlay
    // show a "Resume" label while paused — scope to the side panel here,
    // and check the PauseMenu explicitly in its own test below.
    expect(
      find.descendant(
        of: find.byType(GameSidePanel),
        matching: find.text('Resume'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pausing shows the Pause Menu overlay with run stats', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);
    await _tapMode(tester, 'Classic');
    await tester.tap(find.text('Pause'));
    await tester.pump();

    expect(find.byType(PauseMenu), findsOneWidget);
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(PauseMenu),
        matching: find.text('Resume'),
      ),
    );
    await tester.pump();

    expect(find.byType(PauseMenu), findsNothing);
  });

  testWidgets('Pause Menu Settings button opens the Settings screen', (
    WidgetTester tester,
  ) async {
    // Tall enough that the whole Settings list (including the Cloud Backup
    // section near the bottom) is actually built, not just scrolled-past —
    // ListView(children:) still only materializes what's in the viewport.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);
    await _tapMode(tester, 'Classic');
    await tester.tap(find.text('Pause'));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(PauseMenu),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('CLOUD BACKUP'), findsOneWidget);
  });

  testWidgets('Pause Menu Restart requires confirmation, then resets the run', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);
    await _tapMode(tester, 'Classic');
    await tester.tap(find.text('Pause'));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(PauseMenu),
        matching: find.text('Restart'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restart run?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Restart'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PauseMenu), findsNothing);
    expect(find.byType(KeyboardListener), findsOneWidget); // back in-game
  });

  testWidgets(
    'Pause Menu Quit requires confirmation, then returns to mode select',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpApp(tester);
      await _tapMode(tester, 'Classic');
      await tester.tap(find.text('Pause'));
      await tester.pump();

      await tester.tap(find.text('Quit to Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Quit to menu?'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Quit'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What The Tetris'), findsOneWidget);
    },
  );

  testWidgets(
    'the board actually renders at a real size, not collapsed to zero',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpApp(tester);
      await _tapMode(tester, 'Classic');

      final board = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is BoardPainter,
      );
      expect(board, findsOneWidget);
      // A collapsed/near-zero board (e.g. from a stray Stack loosening its
      // constraints) is the exact bug this guards against.
      final size = tester.getSize(board);
      expect(size.width, greaterThan(200));
      expect(size.height, greaterThan(200));
    },
  );
}
