import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatthetetris/models/theme_palette.dart';
import 'package:whatthetetris/services/theme_service.dart';

void main() {
  test('defaults to the neon theme and persists a change', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await ThemeService.create();

    expect(service.current.id, ThemePalette.neon.id);

    await service.setTheme(ThemePalette.colorblindSafe.id);
    expect(service.current.id, ThemePalette.colorblindSafe.id);
  });

  test('every palette assigns a distinct color to all seven pieces', () {
    for (final palette in ThemePalette.all) {
      const names = ['I4', 'L4', 'T4', 'O4', 'S4', 'Z4', 'J4'];
      final colors = names.map(palette.colorFor).toSet();
      expect(
        colors.length,
        names.length,
        reason: '${palette.label} must give every piece a unique color',
      );
    }
  });

  test('an unknown theme id falls back to neon', () {
    expect(ThemePalette.byId('does-not-exist').id, ThemePalette.neon.id);
  });
}
