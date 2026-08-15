import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/game_mode.dart';
import 'cloud_auth_service.dart';
import 'high_score_service.dart';
import 'stats_service.dart';

/// Backs up local progress to Firestore under `users/{uid}` — a *backup*,
/// never the primary store (docs/TECHNICAL_ARCHITECTURE.md SS3.2).
/// `shared_preferences` via [HighScoreService]/[StatsService] stays
/// authoritative for instant, fully-offline reads; this only ever
/// syncs opportunistically and merges by taking each field's best value,
/// so a stale device can never overwrite a better score.
///
/// Deliberate simplification vs. the subcollection sketch in
/// TECHNICAL_ARCHITECTURE.md SS5: everything lives in one document so a
/// merge is a single transaction, not a multi-document batch. Revisit if
/// per-mode documents are ever needed for security-rule granularity.
class CloudBackupService extends ChangeNotifier {
  CloudBackupService(this._auth);

  final CloudAuthService _auth;
  DateTime? _lastSyncedAt;

  bool get available => isFirebaseConfigured && _auth.available;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.uid;
    if (uid == null || !available) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  /// Pushes local saves, keeping the better value per field either way.
  /// Safe to call often (game-over, app background, a periodic timer) —
  /// it's cheap and idempotent.
  Future<void> pushSaves({
    required HighScoreService highScores,
    required StatsService stats,
  }) async {
    final doc = _userDoc;
    if (doc == null) return;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(doc);
        final remote = snapshot.data() ?? <String, dynamic>{};
        final remoteSaves = Map<String, dynamic>.from(
          remote['saves'] as Map? ?? {},
        );

        final mergedSaves = <String, dynamic>{};
        for (final mode in GameMode.values) {
          final remoteMode = Map<String, dynamic>.from(
            remoteSaves[mode.name] as Map? ?? {},
          );
          final remoteScore = remoteMode['bestScore'] as int? ?? 0;
          final remoteLevel = remoteMode['bestLevel'] as int? ?? 1;
          final remoteTime = remoteMode['bestTimeMs'] as int?;
          final localTime = highScores.bestTimeMs(mode);

          mergedSaves[mode.name] = {
            'bestScore': highScores.bestScore(mode) > remoteScore
                ? highScores.bestScore(mode)
                : remoteScore,
            'bestLevel': highScores.bestLevel(mode) > remoteLevel
                ? highScores.bestLevel(mode)
                : remoteLevel,
            // Lower is better for time-attack modes (e.g. Sprint).
            'bestTimeMs': _lowerOrNull(localTime, remoteTime),
          };
        }

        final remoteStats = Map<String, dynamic>.from(
          remote['stats'] as Map? ?? {},
        );
        final mergedStats = {
          'gamesPlayed': _maxInt(stats.gamesPlayed, remoteStats['gamesPlayed']),
          'totalLinesCleared': _maxInt(
            stats.totalLinesCleared,
            remoteStats['totalLinesCleared'],
          ),
          'totalTetrises': _maxInt(
            stats.totalTetrises,
            remoteStats['totalTetrises'],
          ),
          'totalFusionBonuses': _maxInt(
            stats.totalFusionBonuses,
            remoteStats['totalFusionBonuses'],
          ),
          'bestComboEver': _maxInt(
            stats.bestComboEver,
            remoteStats['bestComboEver'],
          ),
          'bestBackToBackEver': _maxInt(
            stats.bestBackToBackEver,
            remoteStats['bestBackToBackEver'],
          ),
          'totalPlaytimeMs': _maxInt(
            stats.totalPlaytimeMs,
            remoteStats['totalPlaytimeMs'],
          ),
          'totalMirrorUses': _maxInt(
            stats.totalMirrorUses,
            remoteStats['totalMirrorUses'],
          ),
          'totalCavityFills': _maxInt(
            stats.totalCavityFills,
            remoteStats['totalCavityFills'],
          ),
          'maxSpeedBoostEver': _maxInt(
            stats.maxSpeedBoostEver,
            remoteStats['maxSpeedBoostEver'],
          ),
        };

        tx.set(doc, {
          'profile': {'updatedAt': FieldValue.serverTimestamp()},
          'saves': mergedSaves,
          'stats': mergedStats,
        }, SetOptions(merge: true));
      });
      _lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Best-effort. Local shared_preferences remains the source of truth
      // regardless of whether this sync succeeded.
    }
  }

  /// Deletes this user's entire document tree. Call before
  /// [CloudAuthService.deleteAccount] — once the Auth user is gone it can
  /// no longer satisfy the security rules that gate this delete.
  Future<bool> deleteAllData() async {
    final doc = _userDoc;
    if (doc == null) return false;
    try {
      await doc.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static int _maxInt(int local, dynamic remote) {
    final remoteInt = remote is int ? remote : 0;
    return local > remoteInt ? local : remoteInt;
  }

  static int? _lowerOrNull(int? local, int? remote) {
    if (local == null) return remote;
    if (remote == null) return local;
    return local < remote ? local : remote;
  }
}
