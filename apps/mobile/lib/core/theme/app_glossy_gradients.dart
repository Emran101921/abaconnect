import 'package:flutter/material.dart';

/// Gradient palettes for glossy 3D action buttons (reference: wellness dashboard).
abstract final class AppGlossyGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6CF0), Color(0xFF5B4FE8)],
  );

  static const LinearGradient secondary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
  );

  static const LinearGradient tertiary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
  );

  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
  );

  static const LinearGradient warning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
  );

  static const LinearGradient info = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
  );

  static const LinearGradient neutral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
  );

  static Color baseShadowColor(LinearGradient gradient) {
    final colors = gradient.colors;
    return Color.lerp(colors.last, Colors.black, 0.35)!;
  }
}
