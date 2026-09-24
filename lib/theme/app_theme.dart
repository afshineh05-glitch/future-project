import 'package:flutter/material.dart';
import 'package:future_project/theme/muscle_up_motion.dart';

class AppTheme {
  // ==========================
  // COLORS
  // ==========================

  // Experimental MuscleUp palette. Legacy names remain aliases for
  // compatibility while this visual language is evaluated on the dashboard.
  static const Color background = Color(0xFF090908);
  static const Color card = Color(0xFF171512);

  static const Color charcoal = Color(0xFF090908);
  static const Color warmCharcoal = Color(0xFF171512);
  static const Color metallicGold = Color(0xFFFFD45A);
  static const Color brightGold = Color(0xFFFFE27A);
  static const Color deepGold = Color(0xFFDFAF32);
  static const Color goldGlow = metallicGold;
  static const Color bronzeGold = Color(0xFF80652F);
  static const Color goldSurface = Color(0xFF2B2418);
  static const Color ivory = Color(0xFFF8F4EA);

  static const Color dashboardCard = Color(0xE6171512);
  static const Color dashboardCardStrong = Color(0xF21B1813);
  static const Color dashboardMutedText = Color(0xFFC9C3B9);

  static const Color primaryGreen = metallicGold;
  static const Color successGreen = Color(0xFF22C55E);

  static const Color aiBlue = Color(0xFF4DA8DA);
  static const Color gold = metallicGold;

  static const Color visionCard = goldSurface;
  static const Color journeyCard = dashboardCard;
  static const Color calorieCard = dashboardCard;

  static const Color textPrimary = Color(0xFFF8F7F3);
  static const Color textSecondary = dashboardMutedText;
  static const Color textOnDark = Color(0xFFF8F7F3);

  static const Color border = metallicGold;
  static const Color rolexGreen = primaryGreen;
  static const Color accentGreen = successGreen;

  // ==========================
  // THEME
  // ==========================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: MuscleUpPageTransitionsBuilder(),
          TargetPlatform.iOS: MuscleUpPageTransitionsBuilder(),
          TargetPlatform.macOS: MuscleUpPageTransitionsBuilder(),
          TargetPlatform.windows: MuscleUpPageTransitionsBuilder(),
          TargetPlatform.linux: MuscleUpPageTransitionsBuilder(),
          TargetPlatform.fuchsia: MuscleUpPageTransitionsBuilder(),
        },
      ),

      brightness: Brightness.dark,

      scaffoldBackgroundColor: background,

      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        onPrimary: charcoal,
        secondary: deepGold,
        onSecondary: charcoal,
        surface: card,
        onSurface: textPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: charcoal,
        foregroundColor: textOnDark,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
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

        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),

        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
      ),

      cardTheme: CardThemeData(
        color: card,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: charcoal,
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ivory,

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
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
      ),

      dividerTheme: const DividerThemeData(color: border, thickness: 1),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: metallicGold,
        linearTrackColor: goldSurface,
        circularTrackColor: goldSurface,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: charcoal,
        indicatorColor: metallicGold,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? charcoal
                : textOnDark,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? metallicGold
                : textOnDark,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: charcoal,
        selectedItemColor: metallicGold,
        unselectedItemColor: Color(0xFFB8B0A3),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: metallicGold,
        foregroundColor: charcoal,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: metallicGold),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: metallicGold,
          foregroundColor: charcoal,
        ),
      ),
    );
  }
}
