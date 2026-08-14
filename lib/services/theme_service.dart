import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_palette.dart';

/// Persists the player's chosen cosmetic theme (docs/GDD.md SS6.5).
class ThemeService extends ChangeNotifier {
  ThemeService(this._prefs);

  static const _keyThemeId = 'theme_id';

  final SharedPreferences _prefs;

  static Future<ThemeService> create() async {
    return ThemeService(await SharedPreferences.getInstance());
  }

  ThemePalette get current =>
      ThemePalette.byId(_prefs.getString(_keyThemeId) ?? ThemePalette.neon.id);

  Future<void> setTheme(String id) async {
    await _prefs.setString(_keyThemeId, id);
    notifyListeners();
  }
}
