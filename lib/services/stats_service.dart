import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_mode.dart';

/// Lifetime, cross-mode stats (docs/GDD.md SS6.1) — the data Achievements
/// (SS6.2) are evaluated against. Everything here is a monotonically
/// increasing counter, so achievements can be derived live from it rather
/// than needing a separately persisted "unlocked" set.
class StatsService extends ChangeNotifier {
  StatsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<StatsService> create() async {
    return StatsService(await SharedPreferences.getInstance());
  }

  int get gamesPlayed => _prefs.getInt('stats_games_played') ?? 0;
  int get totalLinesCleared => _prefs.getInt('stats_total_lines') ?? 0;
  int get totalTetrises => _prefs.getInt('stats_total_tetrises') ?? 0;
  int get totalFusionBonuses => _prefs.getInt('stats_total_fusions') ?? 0;
  int get bestComboEver => _prefs.getInt('stats_best_combo') ?? 0;
  int get bestBackToBackEver => _prefs.getInt('stats_best_b2b') ?? 0;
  int get totalPlaytimeMs => _prefs.getInt('stats_playtime_ms') ?? 0;
  int get totalMirrorUses => _prefs.getInt('stats_total_mirrors') ?? 0;
  int get totalCavityFills => _prefs.getInt('stats_total_cavity_fills') ?? 0;

  /// Peak Arcade manual Speed Boost stack reached in a single run (0-8) —
  /// the basis for the "Overdrive" achievement. `_speedBoost` only ever
  /// increases within a run and resets to 0 at the next `_startGame`, so
  /// its value at game-over already *is* that run's peak.
  int get maxSpeedBoostEver => _prefs.getInt('stats_max_speed_boost') ?? 0;

  Set<String> get modesPlayed =>
      (_prefs.getStringList('stats_modes_played') ?? const []).toSet();

  static const _maxFormHistory = 20;

  /// Recent "form": each entry is one run's score as a fraction (0.0-1.0) of
  /// that mode's personal best *at the time*, oldest first, capped at the
  /// last [_maxFormHistory] runs. Normalizing to a ratio (rather than raw
  /// score) is what makes this safe to plot as a single line even though
  /// runs come from modes with wildly different score scales (a Chill run
  /// and an Ultra run are never compared on the same axis, only each run's
  /// closeness to its own mode's best).
  List<double> get recentForm =>
      (_prefs.getStringList('stats_recent_form') ?? const [])
          .map((s) => double.tryParse(s) ?? 0.0)
          .toList();

  /// Rolls one completed run's tallies into the lifetime totals. Called
  /// once from [GameScreen._endGame]. [formRatio] is this run's score
  /// divided by that mode's best score (see [recentForm]).
  Future<void> recordRun({
    required GameMode mode,
    required int linesCleared,
    required int tetrises,
    required int fusionBonuses,
    required int bestCombo,
    required int bestBackToBack,
    required int playtimeMs,
    int mirrorUses = 0,
    int cavityFills = 0,
    int maxSpeedBoost = 0,
    double? formRatio,
  }) async {
    await _prefs.setInt('stats_games_played', gamesPlayed + 1);
    await _prefs.setInt('stats_total_lines', totalLinesCleared + linesCleared);
    await _prefs.setInt('stats_total_tetrises', totalTetrises + tetrises);
    await _prefs.setInt(
      'stats_total_fusions',
      totalFusionBonuses + fusionBonuses,
    );
    await _prefs.setInt('stats_playtime_ms', totalPlaytimeMs + playtimeMs);
    await _prefs.setInt('stats_total_mirrors', totalMirrorUses + mirrorUses);
    await _prefs.setInt(
      'stats_total_cavity_fills',
      totalCavityFills + cavityFills,
    );
    if (bestCombo > bestComboEver) {
      await _prefs.setInt('stats_best_combo', bestCombo);
    }
    if (bestBackToBack > bestBackToBackEver) {
      await _prefs.setInt('stats_best_b2b', bestBackToBack);
    }
    if (maxSpeedBoost > maxSpeedBoostEver) {
      await _prefs.setInt('stats_max_speed_boost', maxSpeedBoost);
    }
    final modes = modesPlayed..add(mode.name);
    await _prefs.setStringList('stats_modes_played', modes.toList());
    if (formRatio != null) {
      final updated = [...recentForm, formRatio.clamp(0.0, 1.0)];
      if (updated.length > _maxFormHistory) {
        updated.removeRange(0, updated.length - _maxFormHistory);
      }
      await _prefs.setStringList(
        'stats_recent_form',
        updated.map((d) => d.toString()).toList(),
      );
    }
    notifyListeners();
  }
}
