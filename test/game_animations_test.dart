import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/game/game_animations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('triggerShake clamps intensity into a sane range', () {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);

    // t=0.25 lands where sin(t*pi*6) is at its extreme (-1), so the
    // wobble term is non-zero and comparable across both intensities.
    anim.triggerShake(intensity: 0.0);
    anim.shake.value = 0.25;
    final low = anim.shakeOffset;

    anim.triggerShake(intensity: 10.0);
    anim.shake.value = 0.25;
    final high = anim.shakeOffset;

    // Both clamp (0.0 -> 0.4, 10.0 -> 1.6), so high should meaningfully
    // exceed low rather than being identical or unbounded.
    expect(high.dx.abs(), greaterThan(low.dx.abs()));
  });

  test(
    'triggerShake and triggerImpactRing are no-ops under reduced motion',
    () {
      final anim = GameAnimations(vsync: const TestVSync())
        ..reduceMotion = true;
      addTearDown(anim.dispose);

      anim.triggerShake();
      expect(anim.shake.isAnimating, isFalse);

      anim.triggerImpactRing(const Offset(1, 1));
      expect(anim.impactRing.isAnimating, isFalse);
      expect(anim.impactRingOrigin, isNull);
    },
  );

  test('triggerImpactRing records the origin and starts the animation', () {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);

    anim.triggerImpactRing(const Offset(3, 4));

    expect(anim.impactRingOrigin, const Offset(3, 4));
    expect(anim.impactRing.isAnimating, isTrue);
  });

  test('burst count is thinned, not silenced, under reduced motion', () {
    final anim = GameAnimations(vsync: const TestVSync())..reduceMotion = true;
    addTearDown(anim.dispose);

    anim.burst(Offset.zero, Colors.cyan, count: 12);

    expect(anim.activeParticles, isNotEmpty);
    expect(anim.activeParticles.length, lessThan(12));
  });

  test(
    'setComboHeat starts the pulse on a rising edge and stops it at zero',
    () {
      final anim = GameAnimations(vsync: const TestVSync());
      addTearDown(anim.dispose);

      anim.setComboHeat(0.5);
      expect(anim.comboHeat, 0.5);
      expect(anim.comboPulse.isAnimating, isTrue);

      anim.setComboHeat(0);
      expect(anim.comboHeat, 0);
      expect(anim.comboPulse.isAnimating, isFalse);
    },
  );

  test('setComboHeat clamps into 0..1', () {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);

    anim.setComboHeat(5.0);
    expect(anim.comboHeat, 1.0);
  });

  test('triggerLevelUp starts the flash, but not under reduced motion', () {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);

    anim.triggerLevelUp();
    expect(anim.levelUp.isAnimating, isTrue);

    anim.reduceMotion = true;
    anim.levelUp.value = 0;
    anim.triggerLevelUp();
    expect(anim.levelUp.isAnimating, isFalse);
  });

  test('resetForNewRun stops every transient visual and zeroes it out', () {
    final anim = GameAnimations(vsync: const TestVSync());
    addTearDown(anim.dispose);

    // Get everything transient into a mid-flight state a fast "Play Again"
    // could otherwise carry into a fresh run.
    anim.setDanger(true);
    anim.setComboHeat(0.8);
    anim.triggerCelebration();
    anim.triggerLevelUp();
    anim.triggerShake();
    anim.triggerImpactRing(const Offset(2, 2));
    anim.burst(Offset.zero, Colors.cyan, count: 6);
    expect(anim.activeParticles, isNotEmpty);

    anim.resetForNewRun();

    expect(anim.danger.isAnimating, isFalse);
    expect(anim.danger.value, 0);
    expect(anim.comboHeat, 0);
    expect(anim.comboPulse.isAnimating, isFalse);
    expect(anim.celebration.isAnimating, isFalse);
    expect(anim.celebration.value, 0);
    expect(anim.levelUp.isAnimating, isFalse);
    expect(anim.levelUp.value, 0);
    expect(anim.shake.value, 0);
    expect(anim.impactRing.isAnimating, isFalse);
    expect(anim.impactRing.value, 0);
    expect(anim.impactRingOrigin, isNull);
    expect(anim.lockFlash.value, 0);
    expect(anim.lineClear.value, 0);
    expect(anim.activeParticles, isEmpty);

    // setDanger(true) should still work afterward -- resetForNewRun must not
    // leave the internal _inDanger flag stuck in a state that makes the
    // rising-edge check in setDanger a no-op.
    anim.setDanger(true);
    expect(anim.danger.isAnimating, isTrue);
  });
}
