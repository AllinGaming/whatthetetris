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
import 'ui/widgets/app_route_observer.dart';

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

class HalfBlockPyramidApp extends StatefulWidget {
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
  State<HalfBlockPyramidApp> createState() => _HalfBlockPyramidAppState();
}

class _HalfBlockPyramidAppState extends State<HalfBlockPyramidApp> {
  bool _musicKicked = false;

  /// Chill's calm loop is now the one music bed for the whole app (menu
  /// included), but web browsers refuse to play audio until the very first
  /// user gesture -- so instead of firing at app boot (which would just
  /// fail and never retry), this waits for the first tap/click anywhere and
  /// kicks music off then. Harmless to call again on native, where autoplay
  /// isn't restricted.
  void _kickMusicOnFirstTap() {
    if (_musicKicked) return;
    _musicKicked = true;
    unawaited(widget.audio.playMusic(MusicTrack.zen));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.theme, widget.settings]),
      builder: (context, _) => MaterialApp(
        title: 'What The Tetris',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [appRouteObserver],
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: widget.theme.current.accent,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: widget.theme.current.backgroundBottom,
          useMaterial3: true,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(widget.settings.uiScale)),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _kickMusicOnFirstTap(),
            child: child!,
          ),
        ),
        home: StartScreen(
          highScores: widget.highScores,
          audio: widget.audio,
          settings: widget.settings,
          theme: widget.theme,
          stats: widget.stats,
          dailyChallenge: widget.dailyChallenge,
          live: widget.live,
        ),
      ),
    );
  }
}
