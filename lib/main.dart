import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'services/audio_service.dart';
import 'services/daily_challenge_service.dart';
import 'services/high_score_service.dart';
import 'services/live_services.dart';
import 'services/settings_service.dart';
import 'services/stats_service.dart';
import 'services/theme_service.dart';
import 'ui/start_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mobile web can't be orientation-locked from inside the page, so this
  // only constrains the native iOS/Android builds.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Must never be allowed to crash startup — this game has to work fully
  // offline regardless of Firebase's state. Skipped entirely against the
  // placeholder config (see firebase_options.dart): on iOS, Crashlytics
  // eagerly validates the API key during FirebaseApp configuration and
  // aborts the process with an uncatchable native NSException if it's a
  // placeholder, so a try/catch around this call cannot protect against it.
  if (isFirebaseConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // Local-only mode. LiveServices.create() below degrades the same way.
    }
  }

  // Crashlytics has no web SDK, and must never be wired against the
  // placeholder config — both guards keep this dead code today, exactly
  // like every other live service, until a real Firebase project exists.
  if (isFirebaseConfigured && !kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  final highScores = await HighScoreService.create();
  final audio = await AudioService.create();
  final settings = await SettingsService.create();
  final theme = await ThemeService.create();
  final stats = await StatsService.create();
  final dailyChallenge = await DailyChallengeService.create();
  final live = await LiveServices.create();
  unawaited(live.analytics.sessionStart());
  runApp(
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

class HalfBlockPyramidApp extends StatelessWidget {
  const HalfBlockPyramidApp({
    super.key,
    required this.highScores,
    required this.audio,
    required this.settings,
    required this.theme,
    required this.stats,
    required this.dailyChallenge,
    required this.live,
  });

  final HighScoreService highScores;
  final AudioService audio;
  final SettingsService settings;
  final ThemeService theme;
  final StatsService stats;
  final DailyChallengeService dailyChallenge;
  final LiveServices live;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([theme, settings]),
      builder: (context, _) => MaterialApp(
        title: 'What The Tetris',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: theme.current.accent,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: theme.current.backgroundBottom,
          useMaterial3: true,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(settings.uiScale)),
          child: child!,
        ),
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
  }
}
