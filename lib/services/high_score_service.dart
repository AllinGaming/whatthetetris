import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_mode.dart';
import '../models/coop_variant.dart';

/// Persists a best score/level per mode across sessions.
class HighScoreService extends ChangeNotifier {
  HighScoreService(this._prefs);

  static const _multiplayerScoreKey = 'best_score_multiplayer';
  static const _multiplayerMirrorScoreKey = 'best_score_multiplayer_mirror';
  final SharedPreferences _prefs;

  static Future<HighScoreService> create() async {
    return HighScoreService(await SharedPreferences.getInstance());
  }

  int bestScore(GameMode mode) => _prefs.getInt('best_score_${mode.name}') ?? 0;

  int bestLevel(GameMode mode) => _prefs.getInt('best_level_${mode.name}') ?? 1;

  /// Best completed shared-board score on this device. Both peers record the
  /// same team score when a round ends, but each keeps their own local best.
  int get bestMultiplayerScore => _prefs.getInt(_multiplayerScoreKey) ?? 0;

  int bestMultiplayerScoreFor(CoopVariant variant) =>
      _prefs.getInt(_multiplayerKey(variant)) ?? 0;

  String _multiplayerKey(CoopVariant variant) => switch (variant) {
    CoopVariant.fixed => _multiplayerScoreKey,
    CoopVariant.mirror => _multiplayerMirrorScoreKey,
  };

  /// Fastest completion time in milliseconds, for time-attack modes like
  /// Sprint where lower is better — null until a run has ever finished.
  int? bestTimeMs(GameMode mode) => _prefs.getInt('best_time_${mode.name}');

  Future<void> submitRun(
    GameMode mode, {
    required int score,
    required int level,
  }) async {
    var changed = false;
    if (score > bestScore(mode)) {
      changed =
          (await _prefs.setInt('best_score_${mode.name}', score)) || changed;
    }
    if (level > bestLevel(mode)) {
      changed =
          (await _prefs.setInt('best_level_${mode.name}', level)) || changed;
    }
    if (changed) notifyListeners();
  }

  /// Records a completion time for a lower-is-better mode (e.g. Sprint).
  Future<void> submitTime(GameMode mode, int timeMs) async {
    final current = bestTimeMs(mode);
    if (current == null || timeMs < current) {
      await _prefs.setInt('best_time_${mode.name}', timeMs);
      notifyListeners();
    }
  }

  /// Returns true only when [score] became a new local 2 Player best.
  Future<bool> submitMultiplayerScore(
    int score, {
    CoopVariant variant = CoopVariant.fixed,
  }) async {
    if (score <= bestMultiplayerScoreFor(variant)) return false;
    final changed = await _prefs.setInt(_multiplayerKey(variant), score);
    if (changed) notifyListeners();
    return changed;
  }
}
