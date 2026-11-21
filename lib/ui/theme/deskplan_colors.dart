import 'package:flutter/material.dart';

/// DeskPlan's colour tokens (docs/DESIGN.md), as a theme extension so any
/// widget can read them with `DeskPlanColors.of(context)`.
///
/// Material has no slot for `warn`, `ok`, `faint` and the like, so they live
/// here. The rest are also mapped onto the ColorScheme by [AppTheme].
@immutable
class DeskPlanColors extends ThemeExtension<DeskPlanColors> {
  const DeskPlanColors({
    required this.frame,
    required this.bg,
    required this.bgSide,
    required this.card,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderSoft,
    required this.borderHover,
    required this.text,
    required this.muted,
    required this.faint,
    required this.check,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.danger,
    required this.warn,
    required this.ok,
  });

  final Color frame, bg, bgSide, card, surface, surface2;
  final Color border, borderSoft, borderHover;
  final Color text, muted, faint, check;
  final Color accent, accentSoft, onAccent;
  final Color danger, warn, ok;

  static const dark = DeskPlanColors(
    frame: Color(0xFF0C0D12),
    bg: Color(0xFF121319),
    bgSide: Color(0xFF15161D),
    card: Color(0xFF181920),
    surface: Color(0xFF1A1C25),
    surface2: Color(0xFF232532),
    border: Color(0xFF272A37),
    borderSoft: Color(0x0FFFFFFF), // white at 6%
    borderHover: Color(0xFF343849),
    text: Color(0xFFE6E8EF),
    muted: Color(0xFF8B90A3),
    faint: Color(0xFF5D6277),
    check: Color(0xFF4A4F63),
    accent: Color(0xFF7C8CFF),
    accentSoft: Color(0x297C8CFF), // accent at 16%
    onAccent: Color(0xFF0D0F1A),
    danger: Color(0xFFFF6B6B),
    warn: Color(0xFFF5B84B),
    ok: Color(0xFF4CC9A4),
  );

  static const light = DeskPlanColors(
    frame: Color(0xFFE8E6E0),
    bg: Color(0xFFF2F1EC),
    bgSide: Color(0xFFEBE9E3),
    card: Color(0xFFFBFAF8),
    surface: Color(0xFFFAF9F6),
    surface2: Color(0xFFE9E7E0),
    border: Color(0xFFD9D6CD),
    borderSoft: Color(0x0F000000), // black at 6% (DESIGN.md gives none)
    borderHover: Color(0xFFC2BDB1),
    text: Color(0xFF1F1D1A),
    muted: Color(0xFF57534C),
    faint: Color(0xFF8A857B),
    check: Color(0xFF9F9A8F),
    accent: Color(0xFF616DC7), // Indigo darkened 22% for the light theme
    accentSoft: Color(0x21616DC7), // accent at 13%
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC93C3C),
    warn: Color(0xFFA8660B),
    ok: Color(0xFF23866A),
  );

  /// The colour of an assignment's dot and icon, the same in both themes
  /// (docs/DESIGN.md "Item kind colours").
  static const assignmentKind = Color(0xFFFF7A8A);

  /// The colour of a note's icon, the same in both themes.
  static const noteKind = Color(0xFFE6C86E);

  static DeskPlanColors of(BuildContext context) =>
      Theme.of(context).extension<DeskPlanColors>()!;

  @override
  DeskPlanColors copyWith() => this;

  /// The two themes are switched whole, never blended.
  @override
  DeskPlanColors lerp(ThemeExtension<DeskPlanColors>? other, double t) =>
      t < 0.5 || other is! DeskPlanColors ? this : other;
}
