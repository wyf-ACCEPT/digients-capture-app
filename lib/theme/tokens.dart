import 'package:flutter/material.dart';

class DCColors {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color accent;
  final Color accentStrong;
  final Color accentGlow;
  final Color accentTint;
  final Color success;
  final Color warning;
  final Color danger;

  const DCColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.accent,
    required this.accentStrong,
    required this.accentGlow,
    required this.accentTint,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static const dark = DCColors(
    bg: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surface2: Color(0xFF1C1C1C),
    border: Color(0xFF1F1F1F),
    borderStrong: Color(0xFF2A2A2A),
    text: Color(0xFFFAFAF7),
    textDim: Color(0xFF8A8A8A),
    textFaint: Color(0xFF555555),
    accent: Color(0xFF14C9A8),
    accentStrong: Color(0xFF0FB294),
    accentGlow: Color(0x5914C9A8),
    accentTint: Color(0x1414C9A8),
    success: Color(0xFF14C9A8),
    warning: Color(0xFFFFB800),
    danger: Color(0xFFFF453A),
  );

  static const light = DCColors(
    bg: Color(0xFFFAFAF7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF2F1ED),
    border: Color(0xFFE8E6E0),
    borderStrong: Color(0xFFD4D2CB),
    text: Color(0xFF0A0A0A),
    textDim: Color(0xFF6B6B6B),
    textFaint: Color(0xFFA0A0A0),
    accent: Color(0xFF0FA68A),
    accentStrong: Color(0xFF0E8E76),
    accentGlow: Color(0x2E0FA68A),
    accentTint: Color(0x120FA68A),
    success: Color(0xFF0FA68A),
    warning: Color(0xFFE89200),
    danger: Color(0xFFE0322A),
  );
}

class DCColorsExtension extends ThemeExtension<DCColorsExtension> {
  final DCColors colors;
  const DCColorsExtension(this.colors);

  @override
  DCColorsExtension copyWith({DCColors? colors}) =>
      DCColorsExtension(colors ?? this.colors);

  @override
  DCColorsExtension lerp(ThemeExtension<DCColorsExtension>? other, double t) {
    if (other is! DCColorsExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension DCColorsContext on BuildContext {
  DCColors get dc =>
      Theme.of(this).extension<DCColorsExtension>()?.colors ?? DCColors.dark;
}
