import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/services/cloud_auth_service.dart';
import 'package:whatthetetris/services/leaderboard_service.dart';
import 'package:whatthetetris/ui/leaderboard_screen.dart';

class _FakeLeaderboardService extends LeaderboardService {
  _FakeLeaderboardService() : super(CloudAuthService());

  @override
  bool get available => true;

  @override
  bool get currentPlayerIsAnonymous => true;

  @override
  String get currentPlayerShortId => 'ABC123';

  @override
  bool isCurrentPlayer(String uid) => uid == 'me';

  @override
  Future<List<LeaderboardEntry>> fetchTop({
    required GameMode mode,
    bool isDaily = false,
    int? dailySeed,
    int limit = 10,
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<List<LeaderboardEntry>> fetchTopMultiplayer({
    int limit = 10,
    bool forceRefresh = false,
  }) async => const [LeaderboardEntry(uid: 'me', score: 4321, level: 3)];
}

void main() {
  testWidgets('shows an honest not-available state without web Firebase', (
    WidgetTester tester,
  ) async {
    final auth = CloudAuthService();
    await auth.initialize();
    final leaderboard = LeaderboardService(auth);

    await tester.pumpWidget(
      MaterialApp(home: LeaderboardScreen(leaderboard: leaderboard)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("aren't available right now"), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('offers a 2 Player board with shared team scores', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(leaderboard: _FakeLeaderboardService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await tester.tap(find.widgetWithText(ChoiceChip, '2 Player'));
    await tester.pumpAndSettle();

    expect(find.text('Shared-board team best'), findsOneWidget);
    expect(find.text('4321'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });
}
