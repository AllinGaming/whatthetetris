import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/services/cloud_auth_service.dart';
import 'package:whatthetetris/services/leaderboard_service.dart';
import 'package:whatthetetris/ui/leaderboard_screen.dart';

void main() {
  testWidgets(
    'shows an honest not-available state against the placeholder config',
    (WidgetTester tester) async {
      final auth = CloudAuthService();
      await auth.initialize();
      final leaderboard = LeaderboardService(auth);

      await tester.pumpWidget(
        MaterialApp(home: LeaderboardScreen(leaderboard: leaderboard)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("aren't available yet"), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    },
  );
}
