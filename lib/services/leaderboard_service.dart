import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/coop_variant.dart';
import '../models/game_mode.dart';
import 'cloud_auth_service.dart';

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.score,
    required this.level,
  });

  final String uid;
  final String name;
  final int score;
  final int level;
}

/// Lightweight Firestore leaderboards with no Cloud Functions dependency.
/// Only local personal bests are attempted, and a transaction writes only
/// when that score also improves the remote best. Security rules constrain
/// ownership, fields, types, ranges, timestamps, and score direction.
class LeaderboardService {
  LeaderboardService(this._auth);

  final CloudAuthService _auth;
  final Map<String, List<LeaderboardEntry>> _topCache = {};

  bool get available => isFirebaseLeaderboardConfigured && _auth.available;
  bool get currentPlayerIsAnonymous => _auth.isAnonymous;
  String get currentPlayerShortId => _auth.shortPlayerId;
  String get currentPlayerName => _auth.playerName;

  bool isCurrentPlayer(String uid) => uid == _auth.uid;

  CollectionReference<Map<String, dynamic>> _entries({
    required GameMode mode,
    required bool isDaily,
    int? dailySeed,
  }) => isDaily
      ? FirebaseFirestore.instance
            .collection('dailyChallenge')
            .doc('$dailySeed')
            .collection('entries')
      : FirebaseFirestore.instance
            .collection('leaderboards')
            .doc(mode.name)
            .collection('entries');

  CollectionReference<Map<String, dynamic>> _multiplayerEntries(
    CoopVariant variant,
  ) => FirebaseFirestore.instance
      .collection('leaderboards')
      .doc(variant.leaderboardKey)
      .collection('entries');

  /// Uses one document read and performs one write only when [score] beats the
  /// existing remote best. It is never called for an ordinary completed run.
  Future<bool> submitScore({
    required GameMode mode,
    required int score,
    required int level,
    required bool isNewBest,
    bool isDaily = false,
    int? dailySeed,
  }) async {
    if (!available || !isNewBest || score <= 0) return false;
    if (isDaily && dailySeed == null) return false;
    if (isDaily ? mode != GameMode.daily : mode != GameMode.chill) {
      return false;
    }
    return _submitEntry(
      entries: _entries(mode: mode, isDaily: isDaily, dailySeed: dailySeed),
      score: score,
      level: level,
    );
  }

  /// Saves a player's best shared-board team score. Both peers may submit
  /// the same final result, but each writes only their own improving entry.
  Future<bool> submitMultiplayerScore({
    required int score,
    required int level,
    required bool isNewBest,
    CoopVariant variant = CoopVariant.fixed,
  }) async {
    if (!available || !isNewBest || score <= 0) return false;
    return _submitEntry(
      entries: _multiplayerEntries(variant),
      score: score,
      level: level,
    );
  }

  Future<bool> _submitEntry({
    required CollectionReference<Map<String, dynamic>> entries,
    required int score,
    required int level,
  }) async {
    final uid = _auth.uid;
    if (uid == null) return false;
    try {
      final entry = entries.doc(uid);
      var wrote = false;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final existing = await transaction.get(entry);
        final existingScore = existing.data()?['score'];
        if (existingScore is int && existingScore >= score) return;
        transaction.set(entry, {
          'name': _auth.playerName,
          'score': score,
          'level': level,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        wrote = true;
      });
      if (wrote) _topCache.clear();
      return wrote;
    } catch (_) {
      return false;
    }
  }

  /// Refreshes the player's name on only the leaderboard documents that
  /// already exist. A name choice therefore costs zero score-document writes
  /// for a player with no entries, and at most one write for each currently
  /// visible board (Classic, both 2 Player variants, and today's Daily).
  Future<bool> syncCurrentPlayerName({int? dailySeed}) async {
    final uid = _auth.uid;
    if (!available || uid == null) return false;
    final documents = <DocumentReference<Map<String, dynamic>>>[
      _entries(mode: GameMode.chill, isDaily: false).doc(uid),
      _multiplayerEntries(CoopVariant.fixed).doc(uid),
      _multiplayerEntries(CoopVariant.mirror).doc(uid),
      if (dailySeed != null)
        _entries(
          mode: GameMode.daily,
          isDaily: true,
          dailySeed: dailySeed,
        ).doc(uid),
    ];
    try {
      var wrote = false;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final document in documents) {
          snapshots.add(await transaction.get(document));
        }
        for (final snapshot in snapshots) {
          final data = snapshot.data();
          if (data == null) continue;
          final score = data['score'];
          final level = data['level'];
          if (score is! int || level is! int) continue;
          final hasLegacyFields = data.keys.any(
            (key) =>
                !const {'name', 'score', 'level', 'updatedAt'}.contains(key),
          );
          if (data['name'] == _auth.playerName && !hasLegacyFields) continue;
          transaction.set(snapshot.reference, {
            'name': _auth.playerName,
            'score': score,
            'level': level,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          wrote = true;
        }
      });
      if (wrote) _topCache.clear();
      return wrote;
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
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    if (!available) return const [];
    return _fetchEntries(
      entries: _entries(mode: mode, isDaily: isDaily, dailySeed: dailySeed),
      cacheKey: '${mode.name}:${isDaily ? dailySeed : 'all'}:$limit',
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }

  /// Top shared-board scores. An entry is the best team result achieved by
  /// that Firebase player, regardless of which room partner they played with.
  Future<List<LeaderboardEntry>> fetchTopMultiplayer({
    int limit = 10,
    bool forceRefresh = false,
    CoopVariant variant = CoopVariant.fixed,
  }) async {
    if (!available) return const [];
    return _fetchEntries(
      entries: _multiplayerEntries(variant),
      cacheKey: '${variant.leaderboardKey}:all:$limit',
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<LeaderboardEntry>> _fetchEntries({
    required CollectionReference<Map<String, dynamic>> entries,
    required String cacheKey,
    required int limit,
    required bool forceRefresh,
  }) async {
    final cached = _topCache[cacheKey];
    if (!forceRefresh && cached != null) return cached;
    try {
      final snapshot = await entries
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      final leaderboardEntries = snapshot.docs
          .map(
            (doc) => LeaderboardEntry(
              uid: doc.id,
              name: _entryName(doc.id, doc.data()['name']),
              score: doc.data()['score'] as int? ?? 0,
              level: doc.data()['level'] as int? ?? 1,
            ),
          )
          .toList();
      final result = List<LeaderboardEntry>.unmodifiable(leaderboardEntries);
      _topCache[cacheKey] = result;
      return result;
    } catch (_) {
      return const [];
    }
  }

  String _entryName(String uid, Object? value) {
    if (value is String && CloudAuthService.isValidPlayerName(value)) {
      return CloudAuthService.normalizePlayerName(value);
    }
    final length = uid.length < 6 ? uid.length : 6;
    return 'Player ${uid.substring(0, length).toUpperCase()}';
  }
}
