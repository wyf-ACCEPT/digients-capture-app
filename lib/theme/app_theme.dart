import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData buildTheme(DCColors c, Brightness brightness) {
  final base = brightness == Brightness.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: c.accent,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: c.surface2,
      outline: c.borderStrong,
      outlineVariant: c.border,
      error: c.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: c.text,
      displayColor: c.text,
    ),
    dividerColor: c.border,
    iconTheme: IconThemeData(color: c.text),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: [DCColorsExtension(c)],
  );
}
