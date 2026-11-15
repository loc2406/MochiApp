import 'package:flutter/material.dart';

/// The approved design language shared by every application route.
/// Backgrounds deliberately have no dependency on the user's accent.
abstract final class PastelBackgrounds {
  static const labels = {
    'lavender': 'Mây tím',
    'sky': 'Trời xanh',
    'peach': 'Đào sữa',
    'mint': 'Bạc hà',
    'paper': 'Trắng dịu',
    'stone': 'Xám ấm',
  };
  static List<Color> colors(String key, bool dark) {
    final pair = switch (key) {
      'sky' => (const Color(0xFFEAF6FF), const Color(0xFFDCE6FF)),
      'peach' => (const Color(0xFFFFF3EF), const Color(0xFFF5DDEB)),
      'mint' => (const Color(0xFFEFFBF5), const Color(0xFFDCEFEA)),
      'paper' => (const Color(0xFFF8F7FC), const Color(0xFFF8F7FC)),
      'stone' => (const Color(0xFFF0ECE8), const Color(0xFFF0ECE8)),
      _ => (const Color(0xFFF1ECFF), const Color(0xFFDCD4FF)),
    };
    if (!dark) return [pair.$1, pair.$2];
    return [
      Color.lerp(const Color(0xFF10101D), pair.$1, .06)!,
      Color.lerp(const Color(0xFF10101D), pair.$2, .13)!,
    ];
  }
}

abstract final class PastelSpacing {
  static const double xxs = 4,
      xs = 8,
      sm = 12,
      md = 16,
      lg = 24,
      xl = 24,
      xxl = 32,
      huge = 40;
}

abstract final class PastelIconSize {
  static const double md = 22;
}

@immutable
class PastelPalette extends ThemeExtension<PastelPalette> {
  final Color accent, action, onAction, ink, muted, surface, soft, border;
  final bool dark, highContrast;
  const PastelPalette({
    required this.accent,
    required this.action,
    required this.onAction,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.soft,
    required this.border,
    required this.dark,
    required this.highContrast,
  });

  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
  }

  static Color readable(Color color, Color background) {
    var result = color;
    final target = background.computeLuminance() > .4
        ? Colors.black
        : Colors.white;
    for (var i = 0; i < 24 && contrast(result, background) < 4.5; i++) {
      result = Color.lerp(result, target, .12)!;
    }
    return result;
  }

  factory PastelPalette.create(Color accent, bool dark, bool highContrast) {
    final surface = dark ? const Color(0xFF272337) : const Color(0xFFFAF8FF);
    final soft = Color.lerp(surface, accent, dark ? .18 : .09)!;
    final action = readable(readable(accent, surface), soft);
    return PastelPalette(
      accent: accent,
      action: action,
      onAction:
          contrast(Colors.white, accent) >=
              contrast(const Color(0xFF140E2D), accent)
          ? Colors.white
          : const Color(0xFF140E2D),
      ink: dark ? const Color(0xFFF6F2FF) : const Color(0xFF171039),
      muted: dark ? const Color(0xFFCBC2E5) : const Color(0xFF574B79),
      surface: surface,
      soft: soft,
      border: dark ? const Color(0xFF514764) : Colors.white,
      dark: dark,
      highContrast: highContrast,
    );
  }
  static PastelPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PastelPalette>() ??
        PastelPalette.create(
          theme.colorScheme.primary,
          theme.brightness == Brightness.dark,
          false,
        );
  }

  LinearGradient get primary => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(
        accent,
        onAction == Colors.white ? Colors.black : Colors.white,
        .06,
      )!,
      accent,
    ],
  );
  LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, Color.lerp(surface, soft, .6)!],
  );
  List<BoxShadow> get shadow => highContrast
      ? []
      : [
          BoxShadow(
            color: (dark ? Colors.black : const Color(0xFF7660C0)).withValues(
              alpha: dark ? .18 : .08,
            ),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -10,
          ),
        ];
  @override
  PastelPalette copyWith() => this;
  @override
  PastelPalette lerp(covariant PastelPalette? other, double t) =>
      other == null || t < .5 ? this : other;
}

abstract final class PastelTheme {
  static ThemeData build({
    required Color accent,
    required Brightness brightness,
    bool highContrast = false,
  }) {
    final p = PastelPalette.create(
      accent,
      brightness == Brightness.dark,
      highContrast,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: brightness,
          ).copyWith(
            primary: p.action,
            onPrimary: PastelPalette.contrast(Colors.white, p.action) >= 4.5
                ? Colors.white
                : p.ink,
            surface: p.surface,
            onSurface: p.ink,
            onSurfaceVariant: p.muted,
            primaryContainer: p.soft,
            onPrimaryContainer: p.ink,
            outlineVariant: p.border,
            surfaceTint: Colors.transparent,
          ),
    );
    final text = base.textTheme
        .apply(bodyColor: p.ink, displayColor: p.ink)
        .copyWith(
          headlineSmall: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
            color: p.ink,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: p.ink,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.55,
            color: p.ink,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.5,
            color: p.muted,
          ),
        );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: Colors.transparent,
      extensions: [p],
      primaryColor: p.accent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: p.action),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: p.border),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAction,
        elevation: 2,
        shape: const StadiumBorder(),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.action,
        unselectedLabelColor: p.muted,
        indicatorColor: p.accent,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAction,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.action,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: p.border),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.action,
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.action),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface,
        contentTextStyle: text.bodyMedium,
        actionTextColor: p.action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.action,
        selectionColor: p.accent.withValues(alpha: .25),
        selectionHandleColor: p.action,
      ),
      dividerColor: p.border,
      iconTheme: IconThemeData(color: p.action, size: 22),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAction,
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.soft,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.soft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.soft,
        selectedColor: p.soft,
        labelStyle: TextStyle(color: p.ink),
        side: BorderSide(color: p.border),
      ),
    );
  }
}
