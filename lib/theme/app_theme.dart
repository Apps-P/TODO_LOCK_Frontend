import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.softwhite,
    fontFamily: 'Pretendard',
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

  );
}
