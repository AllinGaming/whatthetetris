import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the local Daily Challenge on a seed derived from today's date so
/// every attempt sees the same board and piece order that day. Players may
/// retry freely; the service keeps their best result while streaks and the
/// completion counter advance at most once per calendar day.
///
/// The seed and progress tracking remain device-local. There is no trusted
/// server clock or score validation, so changing the device clock or modifying
/// the client can affect the lightweight shared leaderboard. See
/// docs/TECHNICAL_ARCHITECTURE.md SS4.
class DailyChallengeService extends ChangeNotifier {
  DailyChallengeService(this._prefs);

  final SharedPreferences _prefs;

  static Future<DailyChallengeService> create() async {
    return DailyChallengeService(await SharedPreferences.getInstance());
  }

  static String _todayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';

  static String _dateKeyOffset(int daysAgo) =>
      _todayKey(DateTime.now().subtract(Duration(days: daysAgo)));

  /// Deterministic per-day seed — the same calendar date always yields the
  /// same int, so the piece bag (already seedable) reproduces an identical
  /// run for everyone who plays on that date.
  static int seedForToday() => int.parse(_todayKey(DateTime.now()));

  String? get _lastPlayedDateKey => _prefs.getString('daily_last_played_date');

  bool get playedToday => _lastPlayedDateKey == _todayKey(DateTime.now());

  int? get todaysScore =>
      playedToday ? _prefs.getInt('daily_last_score') : null;

  /// Whether today's attempt completed the puzzle goal, as opposed to ending
  /// by topping out first (docs/GDD.md — Daily Challenge redesign,
  /// [EndCondition.boardReducedToOneRow]).
  bool get todaysCleared =>
      playedToday && (_prefs.getBool('daily_last_cleared') ?? false);

  /// Lifetime count of completed Daily Challenge runs — the basis for the
  /// "Daily Challenger" achievement (docs/GDD.md SS6.2).
  int get completedCount => _prefs.getInt('daily_completed_count') ?? 0;

  /// Consecutive-day streak (docs/GDD.md SS6.3). Lazily invalidated: if the
  /// player hasn't played today or yesterday, this reads as 0 even before
  /// their next run explicitly resets the stored counter, so the flame on
  /// mode-select never shows a stale streak.
  int get currentStreak {
    final stored = _prefs.getInt('daily_streak') ?? 0;
    if (stored == 0) return 0;
    final last = _lastPlayedDateKey;
    if (last == _todayKey(DateTime.now()) || last == _dateKeyOffset(1)) {
      return stored;
    }
    return 0;
  }

  Future<void> recordResult(int score, {bool cleared = false}) async {
    final today = _todayKey(DateTime.now());
    if (_lastPlayedDateKey == today) {
      // Retries improve today's stored result without inflating a daily
      // streak or the unique-day completion count.
      var changed = false;
      if (score > (todaysScore ?? 0)) {
        await _prefs.setInt('daily_last_score', score);
        changed = true;
      }
      if (cleared && !todaysCleared) {
        await _prefs.setBool('daily_last_cleared', true);
        changed = true;
      }
      if (changed) notifyListeners();
      return;
    }
    final previousDate = _lastPlayedDateKey;
    final continuesStreak = previousDate == _dateKeyOffset(1);
    final newStreak = continuesStreak ? currentStreak + 1 : 1;

    await _prefs.setString('daily_last_played_date', today);
    await _prefs.setInt('daily_last_score', score);
    await _prefs.setBool('daily_last_cleared', cleared);
    await _prefs.setInt('daily_completed_count', completedCount + 1);
    await _prefs.setInt('daily_streak', newStreak);
    notifyListeners();
  }
}
