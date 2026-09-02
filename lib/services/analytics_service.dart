import 'package:firebase_analytics/firebase_analytics.dart';

import '../firebase_options.dart';
import '../models/game_mode.dart';

/// Thin wrapper over Firebase Analytics matching the event taxonomy in
/// docs/TECHNICAL_ARCHITECTURE.md/docs/GDD.md SS11. Every method is a no-op
/// when Firebase isn't actually configured, so call sites never need to
/// check availability themselves — this is the one place that knows.
///
/// Deliberately typed methods per event, not a bag-of-strings `log(name)`
/// call scattered through gameplay code: renaming or re-parameterizing an
/// event later means changing one method here, not hunting every call site.
class AnalyticsService {
  FirebaseAnalytics? get _analytics =>
      isFirebaseAnalyticsConfigured ? FirebaseAnalytics.instance : null;

  Map<String, Object>? _firebaseParameters(Map<String, Object>? params) =>
      params?.map(
        (name, value) =>
            MapEntry(name, value is bool ? (value ? 1 : 0) : value),
      );

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      // Firebase custom events support String and numeric values, not bool.
      // Keep call sites expressive while transmitting booleans as 1 or 0.
      await _analytics?.logEvent(
        name: name,
        parameters: _firebaseParameters(params),
      );
    } catch (_) {
      // Analytics must never be able to crash or block gameplay.
    }
  }

  Future<void> identifyAnonymousPlayer(String? uid) async {
    try {
      // Firebase anonymous UIDs contain no name/email and let Analytics join
      // this player's future events across visits on the same auth account.
      // Passing null clears the previous ID when the player changes account.
      await _analytics?.setUserId(id: uid);
    } catch (_) {
      // Identity enrichment must never affect startup or gameplay.
    }
  }

  Future<void> screenViewed(String screen) async {
    try {
      await _analytics?.logScreenView(screenName: screen, screenClass: screen);
    } catch (_) {
      // Screen measurement is best-effort.
    }
  }

  Future<void> _setProperty(String name, String value) async {
    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (_) {
      // Audience properties are best-effort.
    }
  }

  /// Firebase already collects its reserved `session_start` event. This
  /// custom app event marks completion of our own startup path.
  Future<void> sessionStart() => _log('app_opened');

  Future<void> modeSelected(GameMode mode) async {
    await _setProperty('last_mode', mode.name);
    await _log('mode_selected', {'mode': mode.name});
  }

  Future<void> gameStart(GameMode mode) =>
      _log('game_start', {'mode': mode.name});

  Future<void> gameOver({
    required GameMode mode,
    required int score,
    required int level,
    required int lines,
    required int durationMs,
    required bool isNewBest,
    int speedBonus = 0,
  }) => _log('game_over', {
    'mode': mode.name,
    'score': score,
    'level': level,
    'lines': lines,
    'duration_ms': durationMs,
    'is_new_best': isNewBest,
    'speed_bonus': speedBonus,
  });

  Future<void> featureSelected(String feature) =>
      _log('feature_selected', {'feature': feature});

  Future<void> dailyRetry({required bool previouslyCleared}) =>
      _log('daily_retry', {'previously_cleared': previouslyCleared});

  Future<void> multiplayerLobbyViewed({
    required bool available,
    String variant = 'fixed',
  }) => _log('multiplayer_lobby_viewed', {
    'available': available,
    'variant': variant,
  });

  Future<void> multiplayerLobbyAction({
    required String action,
    required String result,
    String variant = 'fixed',
  }) => _log('multiplayer_lobby_action', {
    'action': action,
    'result': result,
    'variant': variant,
  });

  Future<void> multiplayerConnection({
    required String result,
    required String role,
    required int waitMs,
    String variant = 'fixed',
  }) => _log('multiplayer_connection', {
    'result': result,
    'role': role,
    'wait_ms': waitMs,
    'variant': variant,
  });

  Future<void> multiplayerRoundStarted({
    required String role,
    required int roundNumber,
    String variant = 'fixed',
  }) async {
    final mode = switch (variant) {
      'mirror' => 'multiplayer_mirror',
      'puzzle' => 'multiplayer_puzzle',
      _ => 'multiplayer',
    };
    await _setProperty('last_mode', mode);
    await _log('multiplayer_round_started', {
      'role': role,
      'round_number': roundNumber,
      'variant': variant,
    });
  }

  Future<void> multiplayerRoundEnded({
    required String role,
    required String reason,
    required int roundNumber,
    required int durationMs,
    required int score,
    required int lines,
    required int moves,
    required int rotations,
    required int softDrops,
    required int hardDrops,
    int speedBonus = 0,
    String variant = 'fixed',
  }) => _log('multiplayer_round_ended', {
    'role': role,
    'reason': reason,
    'round_number': roundNumber,
    'duration_ms': durationMs,
    'score': score,
    'lines': lines,
    'moves': moves,
    'rotations': rotations,
    'soft_drops': softDrops,
    'hard_drops': hardDrops,
    'speed_bonus': speedBonus,
    'variant': variant,
  });

  Future<void> multiplayerRestarted({
    required String role,
    required int completedRounds,
    String variant = 'fixed',
  }) => _log('multiplayer_restarted', {
    'role': role,
    'completed_rounds': completedRounds,
    'variant': variant,
  });

  Future<void> lineClear(int count) => _log('line_clear', {'count': count});

  Future<void> fourLineClear() => _log('four_line_clear');

  Future<void> fusionBonus(int fusedCells) =>
      _log('fusion_bonus', {'fused_cells': fusedCells});

  Future<void> combo(int comboCount) =>
      _log('combo', {'combo_count': comboCount});

  Future<void> mirrorUsed() => _log('mirror_used');

  Future<void> cavityFillUsed() => _log('cavity_fill_used');

  Future<void> speedBoostUsed(int stacks) =>
      _log('speed_boost_used', {'stacks': stacks});

  Future<void> settingsChanged(String setting, String value) =>
      _log('settings_changed', {'setting': setting, 'value': value});

  Future<void> backupRestored(bool success) =>
      _log('backup_restore', {'success': success});

  Future<void> paywallViewed(String placement) =>
      _log('iap_view_paywall', {'placement': placement});

  Future<void> purchaseSucceeded(String productId) =>
      _log('iap_purchase_success', {'product_id': productId});

  Future<void> purchaseCancelled(String productId) =>
      _log('iap_purchase_cancel', {'product_id': productId});
}
