import 'package:flutter/material.dart';

import 'deskplan_colors.dart';

/// Builds the app's [ThemeData] from [DeskPlanColors] (docs/DESIGN.md).
/// `MaterialApp` picks light or dark from the phone's system setting.
class AppTheme {
  static final ThemeData light = _build(DeskPlanColors.light, Brightness.light);
  static final ThemeData dark = _build(DeskPlanColors.dark, Brightness.dark);

  static ThemeData _build(DeskPlanColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.onAccent,
      surface: c.bg,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.surface2,
      outline: c.border,
      outlineVariant: c.borderSoft,
    );
    final radius8 = BorderRadius.circular(8);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.frame,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Flat, thin borders, no shadows (except things that float).
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.borderSoft),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.borderSoft, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: radius8,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius8,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius8,
          borderSide: BorderSide(color: c.accent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          shape: RoundedRectangleBorder(borderRadius: radius8),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: c.check, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.ok : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surface2,
        ),
        trackOutlineColor: WidgetStatePropertyAll(c.border),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.card,
        contentTextStyle: TextStyle(color: c.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.borderSoft),
        ),
      ),
    );
  }
}
