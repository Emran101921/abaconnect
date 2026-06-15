import 'package:flutter/material.dart';

/// Gradient palettes for glossy 3D pill buttons.
abstract final class AppGlossyGradients {
  /// Teal → blue
  static const LinearGradient tealBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF3B82F6)],
  );

  /// Blue → purple
  static const LinearGradient bluePurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF60A5FA), Color(0xFF7C3AED)],
  );

  /// Orange → red
  static const LinearGradient orangeRed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB923C), Color(0xFFEF4444)],
  );

  /// Green → teal
  static const LinearGradient greenTeal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4ADE80), Color(0xFF14B8A6)],
  );

  /// Red → dark red
  static const LinearGradient redDarkRed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF87171), Color(0xFF991B1B)],
  );

  static const LinearGradient primary = bluePurple;

  static const LinearGradient secondary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
  );

  static const LinearGradient tertiary = tealBlue;

  static const LinearGradient success = greenTeal;

  static const LinearGradient warning = orangeRed;

  static const LinearGradient info = tealBlue;

  static const LinearGradient neutral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
  );

  static const LinearGradient danger = redDarkRed;

  static Color baseShadowColor(LinearGradient gradient) {
    final colors = gradient.colors;
    return Color.lerp(colors.last, Colors.black, 0.38)!;
  }

  static Color glowColor(LinearGradient gradient) {
    return gradient.colors.first.withValues(alpha: 0.55);
  }
}
