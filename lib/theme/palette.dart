import 'package:flutter/material.dart';

/// Shared colors and text styles giving the whole app the same
/// warm, glowing "night carnival" look established by the artwork.
class Palette {
  Palette._();

  static const Color nightPurple = Color(0xFF1B0B33);
  static const Color deepPurple = Color(0xFF2A0E4A);
  static const Color velvet = Color(0xFF3A1461);
  static const Color gold = Color(0xFFFFC94A);
  static const Color amber = Color(0xFFFFA53E);
  static const Color hotPink = Color(0xFFFF4D9D);
  static const Color emerald = Color(0xFF3DDC97);
  static const Color sky = Color(0xFF4AC7FF);
  static const Color danger = Color(0xFFFF4757);
  static const Color cream = Color(0xFFFFF6E4);

  static const LinearGradient backdropFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xCC1B0B33),
      Color(0x001B0B33),
      Color(0x001B0B33),
      Color(0xCC1B0B33),
    ],
    stops: [0.0, 0.22, 0.72, 1.0],
  );

  static const TextStyle display = TextStyle(
    fontFamily: 'Fredoka',
    fontWeight: FontWeight.w700,
    color: cream,
    letterSpacing: 0.5,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Baloo2',
    fontWeight: FontWeight.w500,
    color: cream,
  );

  static List<Shadow> glowShadow(Color color, {double blur = 18}) => [
    Shadow(color: color.withValues(alpha: 0.9), blurRadius: blur),
    Shadow(color: color.withValues(alpha: 0.5), blurRadius: blur * 2),
  ];
}
