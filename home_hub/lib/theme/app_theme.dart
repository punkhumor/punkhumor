import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF14201C);
  static const moss = Color(0xFF1F6F5B);
  static const leaf = Color(0xFF2FA37C);
  static const sun = Color(0xFFE8A317);
  static const mist = Color(0xFFE8F2EE);
  static const cloud = Color(0xFFF4F8F6);
  static const line = Color(0xFFD5E4DD);
  static const danger = Color(0xFFC4473A);
}

class AppTheme {
  static const _font = 'HubSans';

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: _font,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.moss,
        brightness: Brightness.light,
        primary: AppColors.moss,
        secondary: AppColors.sun,
        surface: AppColors.cloud,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cloud,
      textTheme: base.textTheme.apply(
        fontFamily: _font,
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        indicatorColor: AppColors.mist,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.moss
                : AppColors.ink.withValues(alpha: 0.55),
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.moss,
        foregroundColor: Colors.white,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.moss,
        thumbColor: AppColors.moss,
        inactiveTrackColor: AppColors.line,
        overlayColor: AppColors.moss.withValues(alpha: 0.12),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: _font,
          color: Colors.white,
        ),
      ),
    );
  }
}
