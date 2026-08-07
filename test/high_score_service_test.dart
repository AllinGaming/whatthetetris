import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/models/game_mode.dart';
import 'package:whatthetetris/services/high_score_service.dart';

void main() {
  test('defaults to 0/1 and only records improvements, per mode', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await HighScoreService.create();

    expect(service.bestScore(GameMode.classic), 0);
    expect(service.bestLevel(GameMode.classic), 1);

    await service.submitRun(GameMode.classic, score: 500, level: 3);
    expect(service.bestScore(GameMode.classic), 500);
    expect(service.bestLevel(GameMode.classic), 3);

    // A worse run afterwards must not overwrite the best.
    await service.submitRun(GameMode.classic, score: 100, level: 1);
    expect(service.bestScore(GameMode.classic), 500);
    expect(service.bestLevel(GameMode.classic), 3);

    // Arcade's best is tracked independently of Classic's.
    expect(service.bestScore(GameMode.arcade), 0);
  });

  test('notifies listeners only when a persisted best improves', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await HighScoreService.create();
    var notifications = 0;
    service.addListener(() => notifications++);

    await service.submitRun(GameMode.classic, score: 500, level: 3);
    expect(notifications, 1);

    await service.submitRun(GameMode.classic, score: 100, level: 2);
    expect(notifications, 1);
  });
}
