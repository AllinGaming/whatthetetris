import 'package:flutter/material.dart';

import '../ui/widgets/floating_toast.dart';
import 'coop_game_engine.dart';

/// Collapses every award produced by one authoritative co-op action into one
/// readable card. This prevents Fusion, clear, combo, and back-to-back labels
/// from launching on top of each other in the same frame.
ToastData? buildCoopEffectCallout(
  CoopEffectState effect, {
  required Color themeAccent,
}) {
  final playerColor = effect.player.color;
  late final String title;
  late final Color color;
  var big = false;

  if (effect.lineCount >= 4) {
    title = 'TEAM TRIANGLE!';
    color = Colors.amberAccent;
    big = true;
  } else if (effect.comboCount > 1) {
    title = '${effect.comboCount}x TEAM COMBO!';
    color = Color.lerp(
      themeAccent,
      Colors.redAccent,
      (effect.comboCount / 6).clamp(0.0, 1.0),
    )!;
    big = effect.comboCount >= 3;
  } else if (effect.fusionCount > 0) {
    title = 'TEAM FUSION x${effect.fusionCount}';
    color = const Color(0xFFFFD24C);
  } else if (effect.lineCount > 0) {
    title = '${effect.player.name.toUpperCase()} LINE CLEAR!';
    color = playerColor;
  } else if (effect.cavityFill) {
    title = 'CAVITY FILLED';
    color = playerColor;
  } else if (effect.hardDropDistance >= 5 && effect.scoreGain > 0) {
    title = '${effect.player.name.toUpperCase()} HARD DROP';
    color = playerColor;
  } else {
    return null;
  }

  final details = <String>[
    if (effect.scoreGain > 0) 'TEAM +${effect.scoreGain}',
    if (effect.linePoints > 0) 'CLEAR +${effect.linePoints}',
    if (effect.fusionPoints > 0) 'FUSION +${effect.fusionPoints}',
    if (effect.comboBonus > 0) 'COMBO +${effect.comboBonus}',
    if (effect.backToBackBonus > 0) 'BACK-TO-BACK +${effect.backToBackBonus}',
  ];
  return ToastData(
    title,
    color,
    big: big,
    subtitle: details.join('  ·  '),
    duration: big
        ? const Duration(milliseconds: 2400)
        : const Duration(milliseconds: 1850),
    backdrop: true,
  );
}
