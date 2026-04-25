import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DCText {
  static TextStyle inter({
    required double size,
    required FontWeight weight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing ?? -0.01 * size,
      height: height,
    );
  }

  static TextStyle mono({
    required double size,
    required FontWeight weight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing ?? -0.01 * size,
      height: height,
    );
  }

  static TextStyle eyebrow({Color? color, double size = 10}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
      letterSpacing: 0.14 * size,
      height: 1.0,
    );
  }
}
