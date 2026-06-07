import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: isLight
          ? const Color(0xFFDBEAFE)
          : const Color(0xFF1E3A5F),
      onPrimaryContainer:
          isLight ? AppColors.primary : const Color(0xFFBFDBFE),
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: isLight
          ? const Color(0xFFCFFAFE)
          : const Color(0xFF164E63),
      onSecondaryContainer:
          isLight ? const Color(0xFF155E75) : const Color(0xFFA5F3FC),
      tertiary: AppColors.primaryLight,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: isLight ? Colors.white : AppColors.surfaceDark,
      onSurface: isLight ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      onSurfaceVariant:
          isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      outline: isLight ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      outlineVariant:
          isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface:
          isLight ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      onInverseSurface:
          isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      inversePrimary: AppColors.primaryLight,
      surfaceTint: AppColors.primary,
      surfaceContainerHighest: isLight
          ? const Color(0xFFF1F5F9)
          : const Color(0xFF1E293B),
      surfaceContainerHigh: isLight
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF172033),
      surfaceContainer: isLight
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF1E293B),
      surfaceContainerLow: isLight
          ? Colors.white
          : const Color(0xFF0F172A),
      surfaceContainerLowest:
          isLight ? Colors.white : const Color(0xFF020617),
      surfaceBright: isLight ? Colors.white : const Color(0xFF334155),
      surfaceDim: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
    );

    final baseText = isLight
        ? GoogleFonts.plusJakartaSansTextTheme()
        : GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.secondary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: baseText.labelMedium,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.secondary,
        linearTrackColor: colorScheme.outlineVariant,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }
}
