// Black + white + blue theme, copied from the website's css/style.css.
// NO green is used as a primary or status color (owner preference).
// Only black, white and blue are used anywhere: amber and red were
// removed 2026-11-19 at the owner's request. Errors and destructive
// actions use black (ink); the shop fee accent is blue.
// 3D depth comes from layered elevation + shadows, not from color.
// Completed orders use dark blue, pending uses light blue, reviewing
// uses solid blue, rejected / cancelled use black — exactly like the
// website's status pills.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color blue = Color(0xFF2563EB);
  static const Color blueDark = Color(0xFF1E40AF);
  static const Color blueDarker = Color(0xFF1E3A8A);
  static const Color blueLight = Color(0xFFDBEAFE);
  static const Color bluePale = Color(0xFFEFF6FF);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color line = Color(0xFFE2E8F0);
  static const Color bg = Color(0xFFF1F5F9);
  static const Color card = Colors.white;
  static const Color telegram = Color(0xFF229ED9);
  static const Color viber = blueDark;
}

/// Status pill colors, mirroring .pill--* in css/style.css.
/// Returns (background, foreground).
({Color bg, Color fg}) statusPillColors(String status) {
  switch (status) {
    case 'pending':
      return (bg: AppColors.blueLight, fg: AppColors.blueDark);
    case 'reviewing':
      return (bg: AppColors.blue, fg: Colors.white);
    case 'completed':
      return (bg: AppColors.blueDark, fg: Colors.white);
    case 'rejected':
    case 'cancelled':
      return (bg: AppColors.ink, fg: Colors.white);
    default:
      return (bg: AppColors.bluePale, fg: AppColors.blueDark);
  }
}

ThemeData buildTheme() {
  const radius = BorderRadius.all(Radius.circular(14));
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSansMyanmar',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue,
      onPrimary: Colors.white,
      secondary: AppColors.blueDark,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      error: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
      elevation: 6,
      shadowColor: Color(0x400F172A),
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansMyanmar',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      // 3D depth: a raised card with a soft key shadow, no tint.
      elevation: 6,
      shadowColor: Color(0x400F172A),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        // 3D depth: raised button with a blue key shadow.
        elevation: 4,
        shadowColor: Color(0x661E3A8A),
        // Finite width: Size.fromHeight (infinite width) breaks buttons
        // laid out inside Rows — in v1.0.0 it squeezed the profile
        // receiver text to one character per line.
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansMyanmar',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.blue),
        // Must stay finite, see elevatedButtonTheme above.
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansMyanmar',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        textStyle: const TextStyle(
          fontFamily: 'NotoSansMyanmar',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.ink, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.blue,
      labelStyle: const TextStyle(
        fontFamily: 'NotoSansMyanmar',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'NotoSansMyanmar',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      shadowColor: const Color(0x1F0F172A),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 8,
      selectedItemColor: AppColors.blue,
      unselectedItemColor: AppColors.muted,
      selectedLabelStyle: TextStyle(
        fontFamily: 'NotoSansMyanmar',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'NotoSansMyanmar',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      type: BottomNavigationBarType.fixed,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.blueDark,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.blue,
      labelStyle: TextStyle(
        fontFamily: 'NotoSansMyanmar',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'NotoSansMyanmar',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'NotoSansMyanmar',
        fontSize: 14,
        color: Colors.white,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  );
}
