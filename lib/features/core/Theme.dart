import 'package:flutter/material.dart';

class AppColors {
  final Color splash_Screen = Colors.deepPurple;
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
      colorScheme: ColorScheme.fromSeed(seedColor: c.appbar_Color, surface: c.Background),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.Button,
          foregroundColor: c.secondary_Text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
