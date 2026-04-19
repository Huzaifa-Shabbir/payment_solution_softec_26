import 'package:flutter/material.dart';

class AppColors {
  final Color splash_Screen = Colors.teal;
  final Color appbar_Color = Colors.deepPurple;
  final Color Background = Colors.white;
  final Color primary_Text = const Color.fromRGBO(47, 58, 54, 1);
  final Color secondary_Text = Colors.white;
  final Color Border = const Color(0xFF525E75);
  final Color Button = Colors.blueAccent;
}

class AppTheme {
  static ThemeData light() {
    final c = AppColors();
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: c.appbar_Color,
      scaffoldBackgroundColor: c.Background,
      appBarTheme: AppBarTheme(
        backgroundColor: c.appbar_Color,
        foregroundColor: c.secondary_Text,
        elevation: 3,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.secondary_Text),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.Button,
        elevation: 6,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.primary_Text),
        bodyLarge: TextStyle(fontSize: 16, color: c.primary_Text),
        bodyMedium: TextStyle(fontSize: 14, color: c.primary_Text),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary_Text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      colorScheme: ColorScheme.fromSeed(seedColor: c.appbar_Color, background: c.Background),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.Button,
          foregroundColor: c.secondary_Text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final primary = Colors.deepPurple.shade200;
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.grey.shade900,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        elevation: 6,
      ),
      cardTheme: CardThemeData(
        color: Colors.grey.shade800,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey.shade800,
      ),
      colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// Simple ThemeController singleton to manage ThemeMode across the app.
/// Call ThemeController.instance.setThemeMode(...) or toggleTheme() from UI.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  ThemeMode get themeMode => _mode;

  void setThemeMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleBetweenLightDark() {
    if (_mode == ThemeMode.dark) _mode = ThemeMode.light;
    else _mode = ThemeMode.dark;
    notifyListeners();
  }
}
