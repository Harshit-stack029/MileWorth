import 'package:flutter/material.dart';

/// MileWorth visual theme. Category colors follow the spec:
/// blue = Business, amber/yellow = Personal.
class AppColors {
  static const primary = Color(0xFF1565C0); // deep blue — "miles into cash"
  static const business = Color(0xFF1976D2); // blue badge
  static const personal = Color(0xFFF9A825); // yellow badge
  static const uncategorized = Color(0xFF9E9E9E); // grey
  static const money = Color(0xFF2E7D32); // green for deduction $
}

ThemeData buildTheme() {
  final base = ThemeData(
    colorSchemeSeed: AppColors.primary,
    useMaterial3: true,
    brightness: Brightness.light,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
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
