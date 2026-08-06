import 'package:flutter/material.dart';

/// AppColors defines the Phase 1 premium palette for Quevaa.
/// Built around Deep Plum, Warm Cream, Soft Terracotta, Sage Green, Muted Rose, and Warm Gold.
class AppColors {
  AppColors._();

  // Primary Dark / Plum Accent
  static const Color deepPlum = Color(0xFF2E1F27);
  static const Color deepPlumLight = Color(0xFF4A3440);
  static const Color deepPlumContainer = Color(0xFFEDE6EA);

  // Aliases for legacy theme compatibility
  static const Color purplePrimary = Color(0xFF3A2332);
  static const Color purpleLight = Color(0xFF6B4D60);
  static const Color purpleDark = Color(0xFF23141E);
  static const Color purpleContainer = Color(0xFFEDE6EA);

  // Emotional Accent: Terracotta
  static const Color terracottaPrimary = Color(0xFFC86D51);
  static const Color terracottaLight = Color(0xFFE89982);
  static const Color terracottaDark = Color(0xFFA14C33);
  static const Color terracottaContainer = Color(0xFFF9EAE5);

  // Wellness Accent: Sage Green
  static const Color sagePrimary = Color(0xFF678D76);
  static const Color sageLight = Color(0xFF98B8A4);
  static const Color sageDark = Color(0xFF426350);
  static const Color sageContainer = Color(0xFFE6F0EA);

  // Menstruation Accent: Muted Rose
  static const Color mutedRose = Color(0xFFD98880);
  static const Color mutedRoseLight = Color(0xFFF5D6D3);
  static const Color mutedRoseContainer = Color(0xFFFDF0EF);

  // Premium Accent: Gold
  static const Color warmGold = Color(0xFFD4A373);
  static const Color warmGoldPrimary = Color(0xFFD4A373);
  static const Color warmGoldLight = Color(0xFFF3E5D8);
  static const Color warmGoldContainer = Color(0xFFFAF2EB);

  // Backgrounds & Cards (Light Mode: Warm Cream)
  static const Color bgWarmCream = Color(0xFFFAFAF7);
  static const Color bgWarmLight = Color(0xFFFAFAF7);
  static const Color cardSurfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFEFECE6);

  // Backgrounds & Cards (Dark Mode: Deep Plum Dark)
  static const Color bgWarmDark = Color(0xFF1C1318);
  static const Color cardSurfaceDark = Color(0xFF2A1E24);
  static const Color borderDark = Color(0xFF382931);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF2E1F27);
  static const Color textSecondaryLight = Color(0xFF70606A);
  static const Color textPrimaryDark = Color(0xFFF8F5F7);
  static const Color textSecondaryDark = Color(0xFFA899A3);

  // Water Hydration
  static const Color waterBlue = Color(0xFF5B9BD5);
  static const Color waterContainer = Color(0xFFEBF3FA);

  // ── Cycle Phase Semantic Tokens (Light) ──────────────────────────
  static const Color cycleMenstrualConfirmedLight = terracottaPrimary;
  static const Color cycleMenstrualConfirmedTextLight = Color(0xFFFFFFFF);
  static const Color cycleMenstrualPredictedLight = Color(0xFFFCE4DE);
  static const Color cycleMenstrualPredictedBorderLight = Color(0xFFE8A090);
  static const Color cycleFollicularLight = Color(0xFFEBF4ED);
  static const Color cycleFertileWindowLight = Color(0xFFE3F1F0);
  static const Color cycleOvulationLight = Color(0xFFF5ECD8);
  static const Color cycleOvulationBorderLight = Color(0xFF8B6A50);
  static const Color cycleLutealLight = Color(0xFFEDE6F0);

  // ── Cycle Phase Semantic Tokens (Dark) ────────────────────────────
  static const Color cycleMenstrualConfirmedDark = Color(0xFFA85843);
  static const Color cycleMenstrualConfirmedTextDark = Color(0xFFF8F5F7);
  static const Color cycleMenstrualPredictedDark = Color(0xFF3D2228);
  static const Color cycleMenstrualPredictedBorderDark = Color(0xFF8B5040);
  static const Color cycleFollicularDark = Color(0xFF1E2E23);
  static const Color cycleFertileWindowDark = Color(0xFF1C2D2C);
  static const Color cycleOvulationDark = Color(0xFF332C1E);
  static const Color cycleOvulationBorderDark = Color(0xFFB89870);
  static const Color cycleLutealDark = Color(0xFF2A2030);
}
