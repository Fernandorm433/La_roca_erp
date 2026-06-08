import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'theme_preference';
  
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(_themeMode);
    notifyListeners();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themePrefKey);
    if (themeString != null) {
      if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (themeString == 'light') {
        _themeMode = ThemeMode.light;
      }
      notifyListeners();
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.dark) {
      prefs.setString(_themePrefKey, 'dark');
    } else if (mode == ThemeMode.light) {
      prefs.setString(_themePrefKey, 'light');
    } else {
      prefs.remove(_themePrefKey);
    }
  }
}
