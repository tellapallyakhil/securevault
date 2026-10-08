import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VaultTheme {
  // Classic Executive Beige & White Palette
  static const Color background = Color(0xFFFBF9F5); // Warm Alabaster Cashmere Cream
  static const Color surface = Color(0xFFFFFFFF); // Pure Crisp White
  static const Color surfaceElevated = Color(0xFFF3EFE6); // Warm Sandstone Beige
  static const Color surfaceBorder = Color(0xFFE5DDD0); // Delicate Warm Greige Border
  
  // Refined Accents: Swiss Champagne Bronze Gold & Espresso
  static const Color primaryCyan = Color(0xFF8C6B38); // Timeless Champagne Bronze Gold
  static const Color secondaryBlue = Color(0xFF4A3E31); // Deep Espresso Earth
  static const Color accentNeon = Color(0xFFA68042); // Warm Polished Gold
  
  // Status Colors (Subtle & Elegant)
  static const Color statusSafe = Color(0xFF2E7D32); // British Racing Emerald Green
  static const Color statusWarning = Color(0xFFC07010); // Warm Amber
  static const Color statusDanger = Color(0xFFC62828); // Rich Crimson

  // Text Colors
  static const Color textPrimary = Color(0xFF1E1A16); // Deep Umber Charcoal
  static const Color textSecondary = Color(0xFF6E6458); // Warm Slate Gray
  static const Color textMuted = Color(0xFF9E9486); // Soft Cashmere

  static ThemeData get classicTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: GoogleFonts.outfit(fontSize: 15, color: textPrimary),
        bodyMedium: GoogleFonts.outfit(fontSize: 13, color: textSecondary),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryCyan,
        secondary: secondaryBlue,
        surface: surface,
        error: statusDanger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shadowColor: const Color(0x0F000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryCyan,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 6,
      ),
    );
  }

  // Alias for backward compatibility
  static ThemeData get darkTheme => classicTheme;
}
