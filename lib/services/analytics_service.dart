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
      isFirebaseConfigured ? FirebaseAnalytics.instance : null;

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics?.logEvent(name: name, parameters: params);
    } catch (_) {
      // Analytics must never be able to crash or block gameplay.
    }
  }

  Future<void> sessionStart() => _log('session_start');

  Future<void> modeSelected(GameMode mode) =>
      _log('mode_selected', {'mode': mode.name});

  Future<void> gameStart(GameMode mode) =>
      _log('game_start', {'mode': mode.name});

  Future<void> gameOver({
    required GameMode mode,
    required int score,
    required int level,
    required int lines,
    required int durationMs,
    required bool isNewBest,
  }) => _log('game_over', {
    'mode': mode.name,
    'score': score,
    'level': level,
    'lines': lines,
    'duration_ms': durationMs,
    'is_new_best': isNewBest,
  });

  Future<void> lineClear(int count) => _log('line_clear', {'count': count});

  Future<void> tetrisClear() => _log('tetris_clear');

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

  Future<void> accountLinkStarted(String provider) =>
      _log('account_link_started', {'provider': provider});

  Future<void> accountLinkResult(String provider, bool success) =>
      _log('account_link_result', {'provider': provider, 'success': success});

  Future<void> backupRestored(bool success) =>
      _log('backup_restore', {'success': success});

  Future<void> paywallViewed(String placement) =>
      _log('iap_view_paywall', {'placement': placement});

  Future<void> purchaseSucceeded(String productId) =>
      _log('iap_purchase_success', {'product_id': productId});

  Future<void> purchaseCancelled(String productId) =>
      _log('iap_purchase_cancel', {'product_id': productId});
}
