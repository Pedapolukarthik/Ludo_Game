import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0D111A);
  static const Color surface = Color(0xFF161F30);
  static const Color cardBg = Color(0xFF1E293B);
  
  static const Color primary = Color(0xFF8B5CF6); // Neon Purple
  static const Color secondary = Color(0xFFEC4899); // Pink Accent
  
  // Ludo Color Palette (Premium Vibrant Colors)
  static const Color ludoRed = Color(0xFFFF3366);
  static const Color ludoGreen = Color(0xFF00E676);
  static const Color ludoYellow = Color(0xFFFFD600);
  static const Color ludoBlue = Color(0xFF2979FF);
  
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Outfit'),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Outfit'),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
      ),
    );
  }

  // Linear Gradients for Premium visual card highlights
  static const LinearGradient purplePinkGradient = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
