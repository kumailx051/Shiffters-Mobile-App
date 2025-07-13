import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.lightPrimary,
        brightness: Brightness.light,
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightSecondary,
        surface: AppColors.lightSurface,
        onPrimary: AppColors.textLight,
        onSecondary: AppColors.textLight,
        onSurface: AppColors.textPrimary,
        tertiary: AppColors.purpleMedium,
        onTertiary: AppColors.textLight,
      ),
      textTheme: _buildTextTheme(AppColors.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.albertSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellowAccent,
          foregroundColor: AppColors.textLight,
          textStyle: GoogleFonts.albertSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 4,
          shadowColor: AppColors.yellowAccent.withOpacity(0.4),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.yellowAccent,
        foregroundColor: AppColors.textLight,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 8,
        shadowColor: AppColors.shadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.lightPrimary,
            width: 2,
          ),
        ),
        hintStyle: GoogleFonts.albertSans(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.albertSans(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundLight,
        selectedItemColor: AppColors.lightPrimary,
        unselectedItemColor: AppColors.grey500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkSecondary,
        surface: AppColors.darkSurface,
        onPrimary: AppColors.textLight,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.darkText,
        tertiary: AppColors.purpleLight,
        onTertiary: AppColors.textPrimary,
      ),
      textTheme: _buildTextTheme(AppColors.darkText),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.albertSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.darkText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkSecondary,
          foregroundColor: AppColors.textPrimary,
          textStyle: GoogleFonts.albertSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 4,
          shadowColor: AppColors.darkSecondary.withOpacity(0.4),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.darkPrimary,
            width: 2,
          ),
        ),
        hintStyle: GoogleFonts.albertSans(
          color: AppColors.grey400,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.albertSans(
          color: AppColors.grey300,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundDark,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.grey500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
      displayLarge: GoogleFonts.albertSans(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.albertSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.albertSans(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -0.3,
      ),
      headlineLarge: GoogleFonts.albertSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.albertSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.albertSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: GoogleFonts.albertSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleMedium: GoogleFonts.albertSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      titleSmall: GoogleFonts.albertSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.albertSans(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textColor,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.albertSans(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textColor,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.albertSans(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textColor,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.albertSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelMedium: GoogleFonts.albertSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelSmall: GoogleFonts.albertSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
    );
  }

  // Gradient decorations for backgrounds
  static BoxDecoration get splashGradient {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.gradientLightLavender,
          AppColors.gradientLightPurple,
          AppColors.gradientMediumLightPurple,
          AppColors.gradientMediumPurple,
          AppColors.gradientDeepPurple,
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ),
    );
  }

  // Custom button styles
  static ButtonStyle get primaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.yellowAccent,
      foregroundColor: AppColors.textLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      elevation: 8,
      shadowColor: AppColors.yellowAccent.withOpacity(0.4),
    );
  }

  static ButtonStyle get secondaryButtonStyle {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.lightPrimary,
      side: const BorderSide(color: AppColors.lightPrimary, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    );
  }
}