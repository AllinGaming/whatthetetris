import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/piece.dart' show PieceColorMode;

/// Which side of the screen the mobile touch controls cluster toward, so a
/// player can reach every control with one thumb (docs/GDD.md SS8).
enum TouchHandedness {
  balanced,
  left,
  right;

  static TouchHandedness fromName(String? name) => values.firstWhere(
    (v) => v.name == name,
    orElse: () => TouchHandedness.balanced,
  );
}

/// Accessibility/feel toggles that are independent of audio (docs/GDD.md SS8).
class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  static const _keyReduceMotion = 'settings_reduce_motion';
  static const _keyHapticsEnabled = 'settings_haptics_enabled';
  static const _keyUiScale = 'settings_ui_scale';
  static const _keyTouchHandedness = 'settings_touch_handedness';
  static const _keySeenTutorial = 'settings_seen_tutorial';
  static const _keyPieceColorMode = 'settings_piece_color_mode';

  final SharedPreferences _prefs;

  static Future<SettingsService> create() async {
    return SettingsService(await SharedPreferences.getInstance());
  }

  bool get reduceMotion => _prefs.getBool(_keyReduceMotion) ?? false;
  bool get hapticsEnabled => _prefs.getBool(_keyHapticsEnabled) ?? true;

  /// Text/UI scale multiplier applied app-wide. 1.0 is the default size.
  double get uiScale => _prefs.getDouble(_keyUiScale) ?? 1.0;

  TouchHandedness get touchHandedness =>
      TouchHandedness.fromName(_prefs.getString(_keyTouchHandedness));

  PieceColorMode get pieceColorMode =>
      PieceColorMode.fromName(_prefs.getString(_keyPieceColorMode));

  /// Whether the first-run "How to Play" overlay has already been shown
  /// (docs/GDD.md SS7 onboarding).
  bool get hasSeenTutorial => _prefs.getBool(_keySeenTutorial) ?? false;

  Future<void> setReduceMotion(bool value) async {
    await _prefs.setBool(_keyReduceMotion, value);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    await _prefs.setBool(_keyHapticsEnabled, value);
    notifyListeners();
  }

  Future<void> setUiScale(double value) async {
    await _prefs.setDouble(_keyUiScale, value);
    notifyListeners();
  }

  Future<void> setTouchHandedness(TouchHandedness value) async {
    await _prefs.setString(_keyTouchHandedness, value.name);
    notifyListeners();
  }

  Future<void> setPieceColorMode(PieceColorMode value) async {
    await _prefs.setString(_keyPieceColorMode, value.name);
    notifyListeners();
  }

  Future<void> setHasSeenTutorial(bool value) async {
    await _prefs.setBool(_keySeenTutorial, value);
    notifyListeners();
  }
}
