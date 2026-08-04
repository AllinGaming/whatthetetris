import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/high_score_service.dart';
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
  final highScores = await HighScoreService.create();
  runApp(HalfBlockPyramidApp(highScores: highScores));
}

class HalfBlockPyramidApp extends StatelessWidget {
  const HalfBlockPyramidApp({super.key, required this.highScores});

  final HighScoreService highScores;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'What The Tetris',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66E0F4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0F16),
        useMaterial3: true,
      ),
      home: StartScreen(highScores: highScores),
    );
  }
}
