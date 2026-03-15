import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.light;
  bool _isDarkMode = false;
  
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;
  
  ThemeService() {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false;
    _isDarkMode = isDark;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
  
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    _themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    
    notifyListeners();
  }
  
  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
    
    notifyListeners();
  }
}
