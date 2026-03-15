import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Clean Professional Light Theme Colors (exactly matching themeReference)
  static const Color _backgroundLight = Color(0xFFF8F9FA);     // Very Light Background
  static const Color _cardWhite = Color(0xFFFFFFFF);          // Pure White Cards
  static const Color _primaryBlue = Color(0xFF4285F4);        // Clean Blue (Google Blue)
  static const Color _accentBlue = Color(0xFF1A73E8);         // Darker Blue
  static const Color _textPrimary = Color(0xFF202124);        // Dark Text
  static const Color _textSecondary = Color(0xFF5F6368);      // Gray Text
  static const Color _textLight = Color(0xFF9AA0A6);          // Light Gray Text
  static const Color _borderLight = Color(0xFFE8EAED);        // Very Light Border
  static const Color _shadowLight = Color(0x0F000000);        // Subtle Shadow
  static const Color _shadowMedium = Color(0x1A000000);       // Medium Shadow
  static const Color _greenAccent = Color(0xFF34A853);        // Green accent
  static const Color _orangeAccent = Color(0xFFFF9800);       // Orange accent
  static const Color _purpleAccent = Color(0xFF9C27B0);       // Purple accent

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryBlue,
        brightness: Brightness.light,
        primary: _primaryBlue,
        secondary: _orangeAccent,
        surface: _cardWhite,
        onPrimary: _cardWhite,
        onSecondary: _cardWhite,
        onSurface: _textPrimary,
        tertiary: _purpleAccent,
        onTertiary: _cardWhite,
        background: _backgroundLight,
        onBackground: _textPrimary,
      ),
      textTheme: _buildLightTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: _cardWhite,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(
          color: _textSecondary,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: _cardWhite,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 4,
          shadowColor: _primaryBlue.withOpacity(0.3),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryBlue,
        foregroundColor: _cardWhite,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      cardTheme: CardThemeData(
        color: _cardWhite,
        elevation: 4,
        shadowColor: _shadowMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryBlue, width: 2),
        ),
        hintStyle: GoogleFonts.inter(
          color: _textLight,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: _textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _backgroundLight,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: _textSecondary,
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
      textTheme: _buildDarkTextTheme(),
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

  // Light Theme Text Theme with Inter Font
  static TextTheme _buildLightTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: _textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _textPrimary,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: _textPrimary,
        letterSpacing: -0.3,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: _textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: _textPrimary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: _textSecondary,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: _textSecondary,
      ),
    );
  }

  // Dark Theme Text Theme with Albert Sans Font
  static TextTheme _buildDarkTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.albertSans(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.albertSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.albertSans(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
        letterSpacing: -0.3,
      ),
      headlineLarge: GoogleFonts.albertSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      headlineMedium: GoogleFonts.albertSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      headlineSmall: GoogleFonts.albertSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      titleLarge: GoogleFonts.albertSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      titleMedium: GoogleFonts.albertSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.darkText,
      ),
      titleSmall: GoogleFonts.albertSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.darkText,
      ),
      bodyLarge: GoogleFonts.albertSans(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.darkText,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.albertSans(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.darkText,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.albertSans(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.darkText,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.albertSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.darkText,
      ),
      labelMedium: GoogleFonts.albertSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.darkText,
      ),
      labelSmall: GoogleFonts.albertSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.darkText,
      ),
    );
  }

  // Gradient decorations for backgrounds (keeping original for compatibility)
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

  // Updated Professional Light Theme Button Styles
  static ButtonStyle get primaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: _primaryBlue,
      foregroundColor: _cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      elevation: 4,
      shadowColor: _primaryBlue.withOpacity(0.3),
    );
  }

  static ButtonStyle get secondaryButtonStyle {
    return OutlinedButton.styleFrom(
      foregroundColor: _primaryBlue,
      side: const BorderSide(color: _primaryBlue, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    );
  }

  // Professional Light Theme Card Style
  static BoxDecoration get professionalCardDecoration {
    return BoxDecoration(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _borderLight, width: 1),
      boxShadow: [
        BoxShadow(
          color: _shadowMedium,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Professional Light Theme Container Style
  static BoxDecoration get professionalContainerDecoration {
    return BoxDecoration(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _borderLight, width: 1),
      boxShadow: [
        BoxShadow(
          color: _shadowMedium,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Professional Light Theme Colors Getters (matching themeReference)
  static Color get lightBackgroundColor => _backgroundLight;
  static Color get lightCardColor => _cardWhite;
  static Color get lightPrimaryColor => _primaryBlue;
  static Color get lightAccentBlue => _accentBlue;
  static Color get lightTextPrimaryColor => _textPrimary;
  static Color get lightTextSecondaryColor => _textSecondary;
  static Color get lightTextLightColor => _textLight;
  static Color get lightBorderColor => _borderLight;
  static Color get lightShadowLight => _shadowLight;
  static Color get lightShadowMedium => _shadowMedium;
  static Color get lightOrangeAccent => _orangeAccent;
  static Color get lightGreenAccent => _greenAccent;
  static Color get lightPurpleAccent => _purpleAccent;
}