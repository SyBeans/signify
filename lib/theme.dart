import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0F172A);
  static const navyLight = Color(0xFF1E293B);
  static const bg = Color(0xFFF5F5F7);
  static const card = Colors.white;
  static const border = Color(0xFFE5E7EB);

  static const blue = Color(0xFF3B82F6);
  static const blueSoft = Color(0xFFDBEAFE);
  static const green = Color(0xFF10B981);
  static const greenSoft = Color(0xFFD1FAE5);
  static const red = Color(0xFFEF4444);
  static const redSoft = Color(0xFFFEE2E2);
  static const orange = Color(0xFFF59E0B);
  static const orangeSoft = Color(0xFFFEF3C7);
  static const grey = Color(0xFF9CA3AF);
  static const greyDark = Color(0xFF4B5563);
  static const textDark = Color(0xFF0F172A);
  static const textSoft = Color(0xFF6B7280);
  static const pinkSoft = Color(0xFFFCE7F3);
  static const pink = Color(0xFFEC4899);

  // Emotion colors (4-class)
  static const emoPositive = green;
  static const emoNegative = red;
  static const emoSurprise = orange;
  static const emoNeutral = grey;
}

class AppText {
  static const header = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );
  static const body = TextStyle(fontSize: 14, color: AppColors.textDark);
  static const small = TextStyle(fontSize: 12, color: AppColors.textSoft);
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textSoft,
  );
}

ThemeData buildSignifyTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
  scaffoldBackgroundColor: AppColors.bg,
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textDark,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: AppColors.card,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
