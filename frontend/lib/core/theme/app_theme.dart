import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF0B0F19); // Rich dark gaming space
  static const Color surface = Color(0xFF131929); // Dark blue surface
  static const Color cardBg = Color(0xFF1A2238); // Premium card backdrop
  
  static const Color primary = Color(0xFF8B5CF6); // Neon Purple
  static const Color secondary = Color(0xFFEC4899); // Neon Pink Accent
  static const Color accentNeon = Color(0xFF00F0FF); // Cyber Cyan Accent
  
  // Ludo Color Palette (Premium Vibrant Hues)
  static const Color ludoRed = Color(0xFFFF2E63);
  static const Color ludoGreen = Color(0xFF08D9D6);
  static const Color ludoYellow = Color(0xFFFFDE7D);
  static const Color ludoBlue = Color(0xFF252A34);
  
  // Real vibrant game tokens
  static const Color tokenRed = Color(0xFFFF3366);
  static const Color tokenGreen = Color(0xFF00E676);
  static const Color tokenYellow = Color(0xFFFFD600);
  static const Color tokenBlue = Color(0xFF2979FF);
  
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFE2E8F0);
  static const Color bronze = Color(0xFFCD7F32);
}

class AppTheme {
  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark();
    final textTheme = GoogleFonts.outfitTextTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withOpacity(0.15), width: 1.5),
        ),
      ),
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 1.2,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 0.8,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        bodyMedium: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shadowColor: AppColors.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  // Linear Gradients for Premium visual card highlights and buttons
  static const LinearGradient purplePinkGradient = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberGradient = LinearGradient(
    colors: [AppColors.accentNeon, AppColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFDF00), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
