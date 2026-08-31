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
  // unconfigured platform (see firebase_options.dart): on iOS, Crashlytics
  // eagerly validates API configuration and can abort with an uncatchable
  // native exception, so the platform-aware guard must run before this call.
  if (isFirebaseConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // Local-only mode. LiveServices.create() below degrades the same way.
    }
  }

  // Crashlytics has no web SDK and native Firebase remains unconfigured, so
  // both guards keep it disabled while web Analytics and rooms are active.
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
  unawaited(live.analytics.screenViewed('mode_select'));
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

class _HalfBlockPyramidAppState extends State<HalfBlockPyramidApp>
    with WidgetsBindingObserver {
  bool _musicKicked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Web browsers refuse to play audio until the first user gesture, so the
  /// calm menu/waiting loop starts on the first tap instead of at app boot.
  void _kickMusicOnFirstTap() {
    if (_musicKicked) return;
    _musicKicked = true;
    unawaited(widget.audio.playMusic(MusicTrack.menu));
  }

  /// Nothing else knows when the whole app leaves the foreground, so keep
  /// lifecycle pausing centralized here even though routes can change tracks.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.audio.resumeMusic());
    } else {
      unawaited(widget.audio.pauseMusic());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.theme, widget.settings]),
      builder: (context, _) => MaterialApp(
        title: 'What The Triangle',
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
