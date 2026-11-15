import 'package:flutter/material.dart';

import '../foundation/mochi_backdrop.dart';
import '../foundation/mochi_palette.dart';
import '../pastel/pastel_theme.dart';
import 'mochi_presets.dart';

/// Application entry point for the approved Pastel design system.
abstract final class MochiTheme {
  static ThemeMode modeFrom(String? stored) => switch (stored) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  static ThemeData light({
    Color? accent,
    MochiVisuals visuals = const MochiVisuals(),
  }) => build(
    accent: accent ?? MochiPresets.violet,
    brightness: Brightness.light,
    visuals: visuals,
  );
  static ThemeData dark({
    Color? accent,
    MochiVisuals visuals = const MochiVisuals(),
  }) => build(
    accent: accent ?? MochiPresets.violet,
    brightness: Brightness.dark,
    visuals: visuals,
  );
  static ThemeData build({
    required Color accent,
    required Brightness brightness,
    MochiVisuals visuals = const MochiVisuals(),
  }) {
    final base = PastelTheme.build(
      accent: accent,
      brightness: brightness,
      highContrast: visuals.highContrast,
    );
    return base.copyWith(
      extensions: [
        ...base.extensions.values,
        MochiPalette.fromAccent(
          accent,
          brightness: brightness,
          highContrast: visuals.highContrast,
        ),
        visuals,
      ],
    );
  }
}
