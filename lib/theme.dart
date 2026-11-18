// Blue + amber theme, copied from the website's css/style.css.
// NO green is used as a primary or status color (owner preference).
// Completed orders use dark blue, pending uses amber, rejected /
// cancelled use red — exactly like the website's status pills.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color blue = Color(0xFF2563EB);
  static const Color blueDark = Color(0xFF1E40AF);
  static const Color blueDarker = Color(0xFF1E3A8A);
  static const Color blueLight = Color(0xFFDBEAFE);
  static const Color bluePale = Color(0xFFEFF6FF);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberDark = Color(0xFFB45309);
  static const Color amberPale = Color(0xFFFEF3C7);
  static const Color red = Color(0xFFDC2626);
  static const Color redPale = Color(0xFFFEE2E2);
  static const Color ink = Color(0xFF1E293B);
  static const Color muted = Color(0xFF64748B);
  static const Color line = Color(0xFFE2E8F0);
  static const Color bg = Color(0xFFF1F5F9);
  static const Color card = Colors.white;
  static const Color telegram = Color(0xFF229ED9);
  static const Color viber = Color(0xFF665CAC);
}

/// Status pill colors, mirroring .pill--* in css/style.css.
/// Returns (background, foreground).
({Color bg, Color fg}) statusPillColors(String status) {
  switch (status) {
    case 'pending':
      return (bg: AppColors.amberPale, fg: AppColors.amberDark);
    case 'reviewing':
      return (bg: AppColors.blueLight, fg: AppColors.blueDark);
    case 'completed':
      return (bg: AppColors.blueDark, fg: Colors.white);
    case 'rejected':
    case 'cancelled':
      return (bg: AppColors.redPale, fg: AppColors.red);
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
      secondary: AppColors.amber,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      error: AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
      elevation: 0,
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
      elevation: 1,
      shadowColor: Color(0x140F172A),
      shape: RoundedRectangleBorder(borderRadius: radius),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
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
        minimumSize: const Size.fromHeight(48),
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
        borderSide: const BorderSide(color: AppColors.red),
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
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
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
