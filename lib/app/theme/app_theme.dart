import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'quevaa_color_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.terracottaPrimary,
      brightness: Brightness.light,
      primary: AppColors.terracottaPrimary,
      secondary: AppColors.sagePrimary,
      tertiary: AppColors.purplePrimary,
      surface: AppColors.cardSurfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgWarmLight,
      colorScheme: colorScheme.copyWith(
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: const Color(0xFFF7F1EC),
      ),
      textTheme: AppTypography.textTheme(false),
      extensions: const [QuevaaColorTokens.light],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimaryLight,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF0ECE6), width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardSurfaceLight,
        selectedItemColor: AppColors.terracottaPrimary,
        unselectedItemColor: AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardSurfaceLight,
        indicatorColor: AppColors.terracottaContainer,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.textTheme(false).labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.terracottaPrimary,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSurfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.terracottaPrimary,
            width: 1.4,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF7F1EC),
        selectedColor: AppColors.terracottaContainer,
        checkmarkColor: AppColors.terracottaPrimary,
        side: const BorderSide(color: AppColors.borderLight),
        labelStyle: AppTypography.textTheme(false).labelLarge,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.terracottaPrimary,
        thumbColor: AppColors.terracottaPrimary,
        inactiveTrackColor: AppColors.borderLight,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardSurfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardSurfaceLight,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.deepPlum,
        contentTextStyle: TextStyle(color: AppColors.textPrimaryDark),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.terracottaLight,
      brightness: Brightness.dark,
      primary: AppColors.terracottaLight,
      secondary: AppColors.sageLight,
      tertiary: AppColors.purpleLight,
      surface: AppColors.cardSurfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgWarmDark,
      colorScheme: colorScheme.copyWith(
        onPrimary: AppColors.bgWarmDark,
        onSecondary: AppColors.bgWarmDark,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: const Color(0xFF34262E),
      ),
      textTheme: AppTypography.textTheme(true),
      extensions: const [QuevaaColorTokens.dark],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimaryDark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2E2A27), width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardSurfaceDark,
        selectedItemColor: AppColors.terracottaLight,
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardSurfaceDark,
        indicatorColor: const Color(0xFF4B2A25),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.textTheme(true).labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.terracottaLight,
        foregroundColor: AppColors.bgWarmDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF241A20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.terracottaLight,
            width: 1.4,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF241A20),
        selectedColor: const Color(0xFF4B2A25),
        checkmarkColor: AppColors.terracottaLight,
        side: const BorderSide(color: AppColors.borderDark),
        labelStyle: AppTypography.textTheme(true).labelLarge,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.terracottaLight,
        thumbColor: AppColors.terracottaLight,
        inactiveTrackColor: AppColors.borderDark,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardSurfaceDark,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF34262E),
        contentTextStyle: TextStyle(color: AppColors.textPrimaryDark),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
