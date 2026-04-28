import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryDark = Color(0xFF00B8CC);
  static const Color primaryLight = Color(0xFF80F2FF);
  static const Color background = Color(0xFFF6F5F2);
  static const Color cardWhite = Color(0xFF1E212B);
  static const Color cardGrey = Color(0xFF2A2E3B);
  static const Color cardMint = Color(0xFF00E5FF);
  static const Color cardPeach = Color(0xFF1E212B);
  static const Color textDark = Color(0xFF161A23);
  static const Color textMedium = Color(0xFF555555);
  static const Color textLight = Color(0xFF888888);
  static const Color barSelected = Color(0xFF00E5FF);
  static const Color barUnselected = Color(0xFF4A5568);

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryLight,
        surface: cardWhite,
      ),
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.dmSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.dmSans(fontSize: 15, color: textMedium),
        bodyMedium: GoogleFonts.dmSans(fontSize: 14, color: textMedium),
      ),
      useMaterial3: true,
    );
  }
}
