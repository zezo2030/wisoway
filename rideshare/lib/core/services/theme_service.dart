import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ThemeService extends ChangeNotifier {
  /// Dark mode is switched off for now, so the app renders light whatever the
  /// system setting or the saved preference says.
  ///
  /// The saved preference is still read and still written, and the appearance
  /// controls in settings are hidden behind this same flag, so turning it back
  /// to true restores the feature and the last choice the user made.
  static const bool darkModeAvailable = false;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => darkModeAvailable ? _themeMode : ThemeMode.light;

  /// The stored preference, ignored while [darkModeAvailable] is false.
  ThemeMode get savedThemeMode => _themeMode;

  ThemeService() {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.keyTheme);
    if (saved != null) {
      ThemeMode found = ThemeMode.system;
      for (final mode in ThemeMode.values) {
        if (mode.name == saved) {
          found = mode;
          break;
        }
      }
      _themeMode = found;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyTheme, mode.name);
  }
}
