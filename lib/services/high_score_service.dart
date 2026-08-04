import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_mode.dart';

/// Persists a best score/level per mode across sessions.
class HighScoreService {
  HighScoreService(this._prefs);

  final SharedPreferences _prefs;

  static Future<HighScoreService> create() async {
    return HighScoreService(await SharedPreferences.getInstance());
  }

  int bestScore(GameMode mode) => _prefs.getInt('best_score_${mode.name}') ?? 0;

  int bestLevel(GameMode mode) => _prefs.getInt('best_level_${mode.name}') ?? 1;

  Future<void> submitRun(
    GameMode mode, {
    required int score,
    required int level,
  }) async {
    if (score > bestScore(mode)) {
      await _prefs.setInt('best_score_${mode.name}', score);
    }
    if (level > bestLevel(mode)) {
      await _prefs.setInt('best_level_${mode.name}', level);
    }
  }
}
