import 'package:flutter/material.dart';

class AppTheme {
  // ==========================
  // COLORS
  // ==========================

  static const Color background = Color(0xFFF8F9F7);
  static const Color card = Colors.white;

  static const Color primaryGreen = Color(0xFF0E5A43);
  static const Color successGreen = Color(0xFF22C55E);

  static const Color aiBlue = Color(0xFF4DA8DA);
  static const Color gold = Color(0xFFF5C84C);

  static const Color visionCard = Color(0xFFEAF8F1);
  static const Color journeyCard = Color(0xFFEAF3FF);
  static const Color calorieCard = Color(0xFFFFF5DF);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color border = Color(0xFFE7EBEE);
  static const Color rolexGreen = primaryGreen;
  static const Color accentGreen = successGreen;

  // ==========================
  // THEME
  // ==========================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.light,

      scaffoldBackgroundColor: background,

      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: aiBlue,
        surface: card,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),

        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),

        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),

        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),

        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
      ),

      cardTheme: CardThemeData(
        color: card,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primaryGreen,
            width: 2,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }
}