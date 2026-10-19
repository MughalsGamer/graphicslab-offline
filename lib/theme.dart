import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0F1117);
  static const surface = Color(0xFF1C1F2A);
  static const surfaceElevated = Color(0xFF252836);
  static const border = Color(0xFF2E3347);
  static const primary = Color(0xFF4D8EFF);
  static const textPrimary = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF9BA8C0);
  static const textMuted = Color(0xFF5C6880);
  static const success = Color(0xFF4CAF7D);
  static const danger = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFFAA44);
  static const accent = Color(0xFFB57BFF);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  OutlineInputBorder ob(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      isDense: true,
      labelStyle:
          const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: ob(AppColors.border),
      enabledBorder: ob(AppColors.border),
      focusedBorder: ob(AppColors.primary, 1.5),
      errorBorder: ob(AppColors.danger),
      focusedErrorBorder: ob(AppColors.danger, 1.5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withOpacity(0.25),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withOpacity(0.25),
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: const TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelTextStyle:
          const TextStyle(color: AppColors.textSecondary, fontSize: 12),
    ),
    dividerColor: AppColors.border,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
