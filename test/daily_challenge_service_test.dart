import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/services/daily_challenge_service.dart';

void main() {
  test(
    'has not been played today by default, and seedForToday is stable',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = await DailyChallengeService.create();

      expect(service.playedToday, isFalse);
      expect(service.todaysScore, isNull);

      final seedA = DailyChallengeService.seedForToday();
      final seedB = DailyChallengeService.seedForToday();
      expect(seedA, seedB);
    },
  );

  test(
    'recording a result marks today as played and stores the score',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = await DailyChallengeService.create();

      await service.recordResult(4200);

      expect(service.playedToday, isTrue);
      expect(service.todaysScore, 4200);
      expect(service.currentStreak, 1);
      expect(service.completedCount, 1);
    },
  );

  String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  test('a run the day after the last one extends the streak', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      'daily_last_played_date': dateKey(yesterday),
      'daily_streak': 5,
      'daily_completed_count': 5,
    });
    final service = await DailyChallengeService.create();

    expect(service.currentStreak, 5); // still alive going into today

    await service.recordResult(100);

    expect(service.currentStreak, 6);
    expect(service.completedCount, 6);
  });

  test(
    'a gap of more than a day resets the streak to zero, then to one',
    () async {
      final longAgo = DateTime.now().subtract(const Duration(days: 5));
      SharedPreferences.setMockInitialValues({
        'daily_last_played_date': dateKey(longAgo),
        'daily_streak': 12,
      });
      final service = await DailyChallengeService.create();

      expect(service.currentStreak, 0); // lazily invalidated, not stale 12

      await service.recordResult(50);

      expect(service.currentStreak, 1);
    },
  );

  test(
    'retries keep the best result without advancing the streak twice',
    () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'daily_last_played_date': dateKey(yesterday),
        'daily_streak': 5,
        'daily_completed_count': 5,
      });
      final service = await DailyChallengeService.create();

      await service.recordResult(100);
      expect(service.currentStreak, 6);
      expect(service.completedCount, 6);
      expect(service.todaysScore, 100);

      await service.recordResult(50);

      expect(service.currentStreak, 6);
      expect(service.completedCount, 6);
      expect(service.todaysScore, 100);

      await service.recordResult(999, cleared: true);

      expect(service.currentStreak, 6);
      expect(service.completedCount, 6);
      expect(service.todaysScore, 999);
      expect(service.todaysCleared, isTrue);
    },
  );
}
