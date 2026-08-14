import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../game/replay.dart';
import '../models/game_mode.dart';
import 'cloud_auth_service.dart';

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.score,
    required this.level,
  });

  final String uid;
  final int score;
  final int level;
}

/// Client side of the score-validation pipeline in
/// docs/TECHNICAL_ARCHITECTURE.md SS4: submits a run's replay to the
/// `submitScore` Cloud Function (`functions/src/index.ts`) rather than
/// writing a score directly — `firestore.rules` makes direct client writes
/// to `leaderboards`/`dailyChallenge` impossible regardless.
///
class LeaderboardService {
  LeaderboardService(this._auth);

  final CloudAuthService _auth;

  bool get available => isFirebaseConfigured && _auth.available;

  /// Returns true only if the Cloud Function actually accepted the score.
  /// A false return (never a thrown exception) covers both "not available"
  /// and "the function rejected this submission."
  Future<bool> submitScore({
    required GameMode mode,
    required int score,
    required int level,
    required Replay replay,
    bool isDaily = false,
  }) async {
    if (!available) return false;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('submitScore');
      final result = await callable.call<Map<String, dynamic>>({
        'mode': mode.name,
        'score': score,
        'level': level,
        'seed': replay.seed,
        'isDaily': isDaily,
        'replay': replay.toJson(),
      });
      return result.data['accepted'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Top [limit] entries for a mode's all-time leaderboard, or (when
  /// [isDaily] is true) for the Daily Challenge identified by [dailySeed].
  /// Returns an empty list rather than throwing when unavailable — callers
  /// render that as "no scores yet" rather than an error state.
  Future<List<LeaderboardEntry>> fetchTop({
    required GameMode mode,
    bool isDaily = false,
    int? dailySeed,
    int limit = 20,
  }) async {
    if (!isFirebaseConfigured) return const [];
    try {
      final collection = isDaily
          ? FirebaseFirestore.instance
                .collection('dailyChallenge')
                .doc('$dailySeed')
                .collection('entries')
          : FirebaseFirestore.instance
                .collection('leaderboards')
                .doc(mode.name)
                .collection('entries');
      final snapshot = await collection
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map(
            (doc) => LeaderboardEntry(
              uid: doc.id,
              score: doc.data()['score'] as int? ?? 0,
              level: doc.data()['level'] as int? ?? 1,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
