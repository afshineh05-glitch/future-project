import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF080808);
  static const Color surface = Color(0xFF151515);
  static const Color rolexGreen = Color(0xFF0B5D3B);
  static const Color accentGreen = Color(0xFF2E8B57);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: rolexGreen,
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}
