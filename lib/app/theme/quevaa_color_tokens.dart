import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class QuevaaColorTokens extends ThemeExtension<QuevaaColorTokens> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color periodConfirmed;
  final Color periodPredicted;
  final Color fertileWindow;
  final Color ovulation;
  final Color spotting;
  final Color highEnergy;
  final Color moderateEnergy;
  final Color lowEnergy;

  const QuevaaColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.periodConfirmed,
    required this.periodPredicted,
    required this.fertileWindow,
    required this.ovulation,
    required this.spotting,
    required this.highEnergy,
    required this.moderateEnergy,
    required this.lowEnergy,
  });

  static const light = QuevaaColorTokens(
    background: AppColors.bgWarmCream,
    surface: AppColors.cardSurfaceLight,
    surfaceElevated: Color(0xFFFFFDFC),
    surfaceMuted: Color(0xFFF7F1EC),
    primary: AppColors.terracottaPrimary,
    primaryContainer: AppColors.terracottaContainer,
    secondary: AppColors.sagePrimary,
    secondaryContainer: AppColors.sageContainer,
    accent: AppColors.warmGoldPrimary,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    textMuted: Color(0xFF91848B),
    border: AppColors.borderLight,
    divider: Color(0xFFE4DED7),
    success: AppColors.sagePrimary,
    warning: AppColors.warmGoldPrimary,
    error: Color(0xFFB94A3D),
    info: AppColors.waterBlue,
    periodConfirmed: AppColors.mutedRose,
    periodPredicted: AppColors.mutedRoseLight,
    fertileWindow: AppColors.sageContainer,
    ovulation: AppColors.purplePrimary,
    spotting: AppColors.terracottaDark,
    highEnergy: AppColors.warmGoldPrimary,
    moderateEnergy: AppColors.sagePrimary,
    lowEnergy: AppColors.purpleLight,
  );

  static const dark = QuevaaColorTokens(
    background: AppColors.bgWarmDark,
    surface: AppColors.cardSurfaceDark,
    surfaceElevated: Color(0xFF34262E),
    surfaceMuted: Color(0xFF241A20),
    primary: AppColors.terracottaLight,
    primaryContainer: Color(0xFF4B2A25),
    secondary: AppColors.sageLight,
    secondaryContainer: Color(0xFF24372D),
    accent: AppColors.warmGold,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textMuted: Color(0xFF887984),
    border: AppColors.borderDark,
    divider: Color(0xFF493940),
    success: AppColors.sageLight,
    warning: AppColors.warmGold,
    error: Color(0xFFFFA193),
    info: Color(0xFF8AC3F4),
    periodConfirmed: Color(0xFFE7A09C),
    periodPredicted: Color(0xFF4B2A31),
    fertileWindow: Color(0xFF284136),
    ovulation: AppColors.purpleLight,
    spotting: AppColors.terracottaLight,
    highEnergy: AppColors.warmGold,
    moderateEnergy: AppColors.sageLight,
    lowEnergy: AppColors.purpleLight,
  );

  @override
  QuevaaColorTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? primary,
    Color? primaryContainer,
    Color? secondary,
    Color? secondaryContainer,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? divider,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? periodConfirmed,
    Color? periodPredicted,
    Color? fertileWindow,
    Color? ovulation,
    Color? spotting,
    Color? highEnergy,
    Color? moderateEnergy,
    Color? lowEnergy,
  }) {
    return QuevaaColorTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      periodConfirmed: periodConfirmed ?? this.periodConfirmed,
      periodPredicted: periodPredicted ?? this.periodPredicted,
      fertileWindow: fertileWindow ?? this.fertileWindow,
      ovulation: ovulation ?? this.ovulation,
      spotting: spotting ?? this.spotting,
      highEnergy: highEnergy ?? this.highEnergy,
      moderateEnergy: moderateEnergy ?? this.moderateEnergy,
      lowEnergy: lowEnergy ?? this.lowEnergy,
    );
  }

  @override
  QuevaaColorTokens lerp(ThemeExtension<QuevaaColorTokens>? other, double t) {
    if (other is! QuevaaColorTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return QuevaaColorTokens(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      primary: mix(primary, other.primary),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      secondary: mix(secondary, other.secondary),
      secondaryContainer: mix(secondaryContainer, other.secondaryContainer),
      accent: mix(accent, other.accent),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      border: mix(border, other.border),
      divider: mix(divider, other.divider),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      info: mix(info, other.info),
      periodConfirmed: mix(periodConfirmed, other.periodConfirmed),
      periodPredicted: mix(periodPredicted, other.periodPredicted),
      fertileWindow: mix(fertileWindow, other.fertileWindow),
      ovulation: mix(ovulation, other.ovulation),
      spotting: mix(spotting, other.spotting),
      highEnergy: mix(highEnergy, other.highEnergy),
      moderateEnergy: mix(moderateEnergy, other.moderateEnergy),
      lowEnergy: mix(lowEnergy, other.lowEnergy),
    );
  }
}

extension QuevaaColorTokenLookup on ThemeData {
  QuevaaColorTokens get quevaa => extension<QuevaaColorTokens>()!;
}
