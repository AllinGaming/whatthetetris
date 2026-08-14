import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'cloud_auth_service.dart';
import 'cloud_backup_service.dart';
import 'leaderboard_service.dart';
import 'purchase_service.dart';

/// Bundles the live-services pieces (docs/TECHNICAL_ARCHITECTURE.md,
/// docs/MONETIZATION.md) into one object so widgets thread a single
/// `live` parameter instead of one more alongside the six local-only
/// services already threaded individually. All of these are safe to
/// construct and use against the placeholder Firebase/RevenueCat config —
/// see lib/firebase_options.dart.
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
    final purchases = PurchaseService();
    await purchases.initialize();
    return LiveServices(
      auth: auth,
      backup: CloudBackupService(auth),
      analytics: AnalyticsService(),
      purchases: purchases,
      leaderboard: LeaderboardService(auth),
    );
  }
}
