import 'dart:async';

import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'cloud_auth_service.dart';
import 'cloud_backup_service.dart';
import 'leaderboard_service.dart';
import 'purchase_service.dart';

/// Bundles the live-services pieces (docs/TECHNICAL_ARCHITECTURE.md,
/// docs/MONETIZATION.md) into one object so widgets thread a single
/// `live` parameter instead of one more alongside the six local-only
/// services already threaded individually. Feature-specific Firebase flags
/// keep unlaunched services safe to construct as no-ops; see
/// lib/firebase_options.dart.
@immutable
class LiveServices {
  const LiveServices({
    required this.auth,
    required this.backup,
    required this.analytics,
    required this.purchases,
    required this.leaderboard,
  });

  final CloudAuthService auth;
  final CloudBackupService backup;
  final AnalyticsService analytics;
  final PurchaseService purchases;
  final LeaderboardService leaderboard;

  static Future<LiveServices> create() async {
    final auth = CloudAuthService();
    await auth.initialize();
    final analytics = AnalyticsService();
    await analytics.identifyAnonymousPlayer(auth.uid);
    auth.addListener(() {
      unawaited(analytics.identifyAnonymousPlayer(auth.uid));
    });
    final purchases = PurchaseService();
    await purchases.initialize();
    return LiveServices(
      auth: auth,
      backup: CloudBackupService(auth),
      analytics: analytics,
      purchases: purchases,
      leaderboard: LeaderboardService(auth),
    );
  }
}
