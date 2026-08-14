import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/services/settings_service.dart';

void main() {
  test(
    'defaults: full scale, balanced handedness, motion/haptics on',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();

      expect(settings.uiScale, 1.0);
      expect(settings.touchHandedness, TouchHandedness.balanced);
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

  test('TouchHandedness.fromName falls back to balanced for garbage input', () {
    expect(TouchHandedness.fromName(null), TouchHandedness.balanced);
    expect(TouchHandedness.fromName('nonsense'), TouchHandedness.balanced);
    expect(TouchHandedness.fromName('left'), TouchHandedness.left);
  });
}
