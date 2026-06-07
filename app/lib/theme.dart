import 'package:flutter/material.dart';

/// MileWorth brand palette (from the brand sheet in /design).
/// Navy = Business, gold = Personal, green = money/deductions.
class AppColors {
  static const navy = Color(0xFF15426F); // brand primary
  static const navyDeep = Color(0xFF0C2640); // brand dark
  static const green = Color(0xFF0FA15D); // brand green
  static const greenLight = Color(0xFF1FD27E);
  static const gold = Color(0xFFF4B740); // brand accent

  static const primary = navy;
  static const business = navy; // blue/navy badge
  static const personal = Color(0xFFC98410); // readable gold for text/badges
  static const uncategorized = Color(0xFF9E9E9E); // grey
  static const money = green; // deduction $
  static const canvas = Color(0xFFF7F5EF); // soft cream background
}

ThemeData buildTheme() {
  final base = ThemeData(
    colorSchemeSeed: AppColors.navy,
    useMaterial3: true,
    brightness: Brightness.light,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
  );
}

/// Color for a trip category string.
Color categoryColor(String category) {
  switch (category) {
    case 'business':
      return AppColors.business;
    case 'personal':
      return AppColors.personal;
    default:
      return AppColors.uncategorized;
  }
}
