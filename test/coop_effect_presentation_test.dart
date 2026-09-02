import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/coop_effect_presentation.dart';
import 'package:whatthetetris/game/coop_game_engine.dart';

void main() {
  CoopEffectState effect({
    int lines = 0,
    int fusions = 0,
    int combo = 0,
    int comboBonus = 0,
    int backToBackBonus = 0,
    int hardDropDistance = 0,
    bool cavityFill = false,
  }) => CoopEffectState(
    id: 1,
    player: CoopPlayer.red,
    cellIndexes: const [10, 11],
    clearedRows: List<int>.generate(lines, (index) => 19 - index),
    fusionCount: fusions,
    fusionPoints: fusions * 25,
    linePoints: lines == 0 ? 0 : 300,
    comboCount: combo,
    comboBonus: comboBonus,
    backToBackCount: backToBackBonus > 0 ? 2 : 0,
    backToBackBonus: backToBackBonus,
    scoreGain: 975,
    hardDropDistance: hardDropDistance,
    cavityFill: cavityFill,
  );

  test('one co-op card preserves every award from a combo event', () {
    final callout = buildCoopEffectCallout(
      effect(
        lines: 2,
        fusions: 2,
        combo: 3,
        comboBonus: 100,
        backToBackBonus: 150,
      ),
      themeAccent: Colors.cyan,
    );

    expect(callout, isNotNull);
    expect(callout!.text, '3x TEAM COMBO!');
    expect(callout.big, isTrue);
    expect(callout.backdrop, isTrue);
    expect(callout.duration, const Duration(milliseconds: 2400));
    expect(callout.subtitle, contains('TEAM +975'));
    expect(callout.subtitle, contains('CLEAR +300'));
    expect(callout.subtitle, contains('FUSION +50'));
    expect(callout.subtitle, contains('COMBO +100'));
    expect(callout.subtitle, contains('BACK-TO-BACK +150'));
  });

  test('Fusion gets a readable card even without a line clear', () {
    final callout = buildCoopEffectCallout(
      effect(fusions: 1),
      themeAccent: Colors.cyan,
    );

    expect(callout!.text, 'TEAM FUSION x1');
    expect(callout.duration, const Duration(milliseconds: 1850));
    expect(callout.subtitle, contains('FUSION +25'));
  });

  test('ordinary locks do not create noisy score cards', () {
    final callout = buildCoopEffectCallout(effect(), themeAccent: Colors.cyan);

    expect(callout, isNull);
  });
}
