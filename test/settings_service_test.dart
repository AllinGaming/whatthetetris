import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/services/settings_service.dart';

void main() {
  test(
    'defaults: full scale, balanced handedness, button controls, motion/haptics on',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();

      expect(settings.uiScale, 1.0);
      expect(settings.touchHandedness, TouchHandedness.balanced);
      expect(settings.touchControlScheme, TouchControlScheme.buttons);
      expect(settings.reduceMotion, isFalse);
      expect(settings.hapticsEnabled, isTrue);
    },
  );

  test('uiScale and touchHandedness persist across changes', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    await settings.setUiScale(1.15);
    expect(settings.uiScale, 1.15);

    await settings.setTouchHandedness(TouchHandedness.left);
    expect(settings.touchHandedness, TouchHandedness.left);

    await settings.setTouchHandedness(TouchHandedness.right);
    expect(settings.touchHandedness, TouchHandedness.right);
  });

  test('touchControlScheme persists across changes', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    await settings.setTouchControlScheme(TouchControlScheme.gestures);
    expect(settings.touchControlScheme, TouchControlScheme.gestures);

    await settings.setTouchControlScheme(TouchControlScheme.buttons);
    expect(settings.touchControlScheme, TouchControlScheme.buttons);
  });

  test('TouchHandedness.fromName falls back to balanced for garbage input', () {
    expect(TouchHandedness.fromName(null), TouchHandedness.balanced);
    expect(TouchHandedness.fromName('nonsense'), TouchHandedness.balanced);
    expect(TouchHandedness.fromName('left'), TouchHandedness.left);
  });

  test(
    'TouchControlScheme.fromName falls back to buttons for garbage input',
    () {
      expect(TouchControlScheme.fromName(null), TouchControlScheme.buttons);
      expect(
        TouchControlScheme.fromName('nonsense'),
        TouchControlScheme.buttons,
      );
      expect(
        TouchControlScheme.fromName('gestures'),
        TouchControlScheme.gestures,
      );
    },
  );
}
