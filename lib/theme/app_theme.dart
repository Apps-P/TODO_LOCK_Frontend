import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.softwhite,
    fontFamily: 'Paperlogy',
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.carrot,
      onPrimary: AppColors.softwhite,
      secondary: AppColors.listbg,
      onSecondary: Color(0xFF3F3F3F),
      error: Colors.red,
      onError: Colors.white,
      surface: AppColors.softwhite,
      onSurface: AppColors.black100,
    ),
    textTheme: const TextTheme(
      // 큰 텍스트 → Medium (w500)
      displayLarge:  TextStyle(fontWeight: FontWeight.w500),
      displayMedium: TextStyle(fontWeight: FontWeight.w500),
      displaySmall:  TextStyle(fontWeight: FontWeight.w500),
      headlineLarge: TextStyle(fontWeight: FontWeight.w500),
      headlineMedium:TextStyle(fontWeight: FontWeight.w500),
      headlineSmall: TextStyle(fontWeight: FontWeight.w500),
      titleLarge:    TextStyle(fontWeight: FontWeight.w500),
      titleMedium:   TextStyle(fontWeight: FontWeight.w500),
      titleSmall:    TextStyle(fontWeight: FontWeight.w500),
      // 기본 텍스트 → Regular (w400)
      bodyLarge:     TextStyle(fontWeight: FontWeight.w400),
      bodyMedium:    TextStyle(fontWeight: FontWeight.w400),
      bodySmall:     TextStyle(fontWeight: FontWeight.w400),
      labelLarge:    TextStyle(fontWeight: FontWeight.w400),
      labelMedium:   TextStyle(fontWeight: FontWeight.w400),
      labelSmall:    TextStyle(fontWeight: FontWeight.w400),
    ),
  );
}