import 'package:flutter/material.dart';

/// Professional healthcare SaaS palette — trustworthy, calm, accessible.
abstract final class AppColors {
  // Brand — clinical blue with teal accent
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color secondary = Color(0xFF0D9488);
  static const Color secondaryLight = Color(0xFF14B8A6);

  static const Color accent = Color(0xFF059669);
  static const Color accentBright = Color(0xFF10B981);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  static const Color riskLow = Color(0xFF16A34A);
  static const Color riskModerate = Color(0xFFD97706);
  static const Color riskHigh = Color(0xFFDC2626);

  // Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF0D9488)],
  );

  static const LinearGradient authHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF0F766E)],
  );

  @Deprecated('Use authHeroGradient')
  static const LinearGradient warmGradient = authHeroGradient;
}
