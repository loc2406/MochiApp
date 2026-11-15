import 'package:flutter/material.dart';

import '../pastel/pastel_theme.dart';

/// Colour math shared by the design system.
abstract final class MochiContrast {
  /// Picks black or white for text drawn on [background], using the WCAG
  /// contrast ratio so yellow/cyan accents still get readable labels.
  static Color on(Color background) {
    final light = 1.05 / (background.computeLuminance() + .05);
    return light >= 4.5 ? Colors.white : const Color(0xFF171226);
  }

  static double ratio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return la > lb ? (la + .05) / (lb + .05) : (lb + .05) / (la + .05);
  }
}

/// Every colour the Mochi interface needs, derived from the user's accent
/// colour and the active brightness. Nothing here is hard-coded per screen:
/// swapping the accent or toggling dark mode recomputes the whole palette.
@immutable
class MochiPalette extends ThemeExtension<MochiPalette> {
  final bool isDark;
  final bool highContrast;

  /// The user's accent, unchanged, used for emphasis and icons.
  final Color accent;
  final Color onAccent;

  final Color pageTop;
  final Color pageBottom;
  final Color blobA;
  final Color blobB;

  /// Card fill, nested surface, hairline border and soft shadow.
  final Color card;
  final Color cardSoft;
  final Color cardBorder;
  final Color shadow;

  final Color ink;
  final Color muted;

  final Color gradientStart;
  final Color gradientEnd;

  /// Accent-tinted fills for icon badges, selected pills and chips.
  final Color softAccent;
  final Color accentBorder;

  final Color navBar;

  final Color success;
  final Color successSoft;
  final Color streak;
  final Color streakSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  final Color chipHighBg;
  final Color chipHighFg;
  final Color chipMediumBg;
  final Color chipMediumFg;
  final Color chipLowBg;
  final Color chipLowFg;

  const MochiPalette({
    required this.isDark,
    required this.highContrast,
    required this.accent,
    required this.onAccent,
    required this.pageTop,
    required this.pageBottom,
    required this.blobA,
    required this.blobB,
    required this.card,
    required this.cardSoft,
    required this.cardBorder,
    required this.shadow,
    required this.ink,
    required this.muted,
    required this.gradientStart,
    required this.gradientEnd,
    required this.softAccent,
    required this.accentBorder,
    required this.navBar,
    required this.success,
    required this.successSoft,
    required this.streak,
    required this.streakSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.chipHighBg,
    required this.chipHighFg,
    required this.chipMediumBg,
    required this.chipMediumFg,
    required this.chipLowBg,
    required this.chipLowFg,
  });

  /// Soft pastel palette: the page is the accent washed into white (light) or
  /// into deep indigo (dark), cards are near-white / lifted indigo.
  factory MochiPalette.fromAccent(
    Color accent, {
    Brightness brightness = Brightness.light,
    bool highContrast = false,
  }) {
    final p = PastelPalette.create(
      accent,
      brightness == Brightness.dark,
      highContrast,
    );
    final page = PastelBackgrounds.colors('lavender', p.dark);
    Color soft(Color tone) => Color.lerp(p.surface, tone, .12)!;
    final success = p.dark ? const Color(0xFF8CE5C9) : const Color(0xFF15715A);
    final warning = p.dark ? const Color(0xFFFFD28F) : const Color(0xFF875000);
    final danger = p.dark ? const Color(0xFFFFA6BB) : const Color(0xFFAF2449);
    return MochiPalette(
      isDark: p.dark,
      highContrast: highContrast,
      accent: accent,
      onAccent: p.onAction,
      pageTop: page.first,
      pageBottom: page.last,
      blobA: page.last,
      blobB: page.first,
      card: p.surface,
      cardSoft: p.soft,
      cardBorder: p.border,
      shadow: p.shadow.isEmpty ? Colors.transparent : p.shadow.first.color,
      ink: p.ink,
      muted: p.muted,
      gradientStart: p.primary.colors.first,
      gradientEnd: p.primary.colors.last,
      softAccent: p.soft,
      accentBorder: p.action.withValues(alpha: .25),
      navBar: p.surface,
      success: success,
      successSoft: soft(success),
      streak: p.dark ? const Color(0xFFF5A623) : const Color(0xFFEA891F),
      streakSoft: soft(p.dark ? const Color(0xFFF5A623) : const Color(0xFFEA891F)),
      warning: warning,
      warningSoft: soft(warning),
      danger: danger,
      dangerSoft: soft(danger),
      chipHighBg: soft(danger),
      chipHighFg: danger,
      chipMediumBg: soft(warning),
      chipMediumFg: warning,
      chipLowBg: soft(success),
      chipLowFg: success,
    );
  }

  Color get action => PastelPalette.create(accent, isDark, highContrast).action;

  static MochiPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MochiPalette>() ??
        MochiPalette.fromAccent(
          const Color(0xFF7C6AF0),
          brightness: theme.brightness,
        );
  }

  LinearGradient get primaryGradient => LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  List<BoxShadow> cardShadow({double opacity = 1}) => highContrast
      ? const []
      : [
          BoxShadow(
            color: shadow.withValues(alpha: shadow.a * opacity),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ];

  List<BoxShadow> get glow => highContrast
      ? const []
      : [
          BoxShadow(
            color: accent.withValues(alpha: .32),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ];

  @override
  MochiPalette copyWith({bool? highContrast}) => MochiPalette(
    isDark: isDark,
    highContrast: highContrast ?? this.highContrast,
    accent: accent,
    onAccent: onAccent,
    pageTop: pageTop,
    pageBottom: pageBottom,
    blobA: blobA,
    blobB: blobB,
    card: card,
    cardSoft: cardSoft,
    cardBorder: cardBorder,
    shadow: shadow,
    ink: ink,
    muted: muted,
    gradientStart: gradientStart,
    gradientEnd: gradientEnd,
    softAccent: softAccent,
    accentBorder: accentBorder,
    navBar: navBar,
      success: success,
      successSoft: successSoft,
      streak: streak,
      streakSoft: streakSoft,
      warning: warning,
    warningSoft: warningSoft,
    danger: danger,
    dangerSoft: dangerSoft,
    chipHighBg: chipHighBg,
    chipHighFg: chipHighFg,
    chipMediumBg: chipMediumBg,
    chipMediumFg: chipMediumFg,
    chipLowBg: chipLowBg,
    chipLowFg: chipLowFg,
  );

  @override
  MochiPalette lerp(covariant MochiPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MochiPalette(
      isDark: t < .5 ? isDark : other.isDark,
      highContrast: t < .5 ? highContrast : other.highContrast,
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      pageTop: l(pageTop, other.pageTop),
      pageBottom: l(pageBottom, other.pageBottom),
      blobA: l(blobA, other.blobA),
      blobB: l(blobB, other.blobB),
      card: l(card, other.card),
      cardSoft: l(cardSoft, other.cardSoft),
      cardBorder: l(cardBorder, other.cardBorder),
      shadow: l(shadow, other.shadow),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      gradientStart: l(gradientStart, other.gradientStart),
      gradientEnd: l(gradientEnd, other.gradientEnd),
      softAccent: l(softAccent, other.softAccent),
      accentBorder: l(accentBorder, other.accentBorder),
      navBar: l(navBar, other.navBar),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      streak: l(streak, other.streak),
      streakSoft: l(streakSoft, other.streakSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      chipHighBg: l(chipHighBg, other.chipHighBg),
      chipHighFg: l(chipHighFg, other.chipHighFg),
      chipMediumBg: l(chipMediumBg, other.chipMediumBg),
      chipMediumFg: l(chipMediumFg, other.chipMediumFg),
      chipLowBg: l(chipLowBg, other.chipLowBg),
      chipLowFg: l(chipLowFg, other.chipLowFg),
    );
  }
}
