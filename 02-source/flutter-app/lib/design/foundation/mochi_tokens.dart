import 'package:flutter/widgets.dart';

/// Spacing scale for the Mochi design language. Values are intentionally
/// generous: cards breathe, buttons are 52 tall and the page gutter is 20.
abstract final class MochiSpacing {
  static const double xxs = 4,
      xs = 8,
      sm = 12,
      md = 16,
      lg = 20,
      xl = 24,
      xxl = 32,
      huge = 40;

  /// Minimum interactive size, kept at 48 so every control stays reachable.
  static const double touch = 48;

  /// Reading width for phones/tablets; desktop stretches layout instead.
  static const double contentMax = 680;

  /// Height of the floating bottom bar, excluding the safe-area inset.
  static const double navBar = 74;

  static const page = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: MochiSpacing.md,
  );
  static const card = EdgeInsets.all(lg);
  static const stack = SizedBox(height: sm);
}

/// Corner radii. Cards are soft (24), sheets rounder (28), chips/badges 12.
abstract final class MochiRadius {
  static const double badge = 12,
      control = 16,
      card = 26,
      sheet = 28,
      pill = 999;

  static const badgeBorder = BorderRadius.all(Radius.circular(badge));
  static const controlBorder = BorderRadius.all(Radius.circular(control));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const sheetBorder = BorderRadius.all(Radius.circular(sheet));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));
}

/// Animation durations shared by every component. Components take the current
/// value from [MediaQuery.disableAnimations] so motion can be reduced globally.
abstract final class MochiMotion {
  static const quick = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;

  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Icon sizes used inside cards, buttons and the navigation bar.
abstract final class MochiIconSize {
  static const double xs = 16, sm = 18, md = 22, lg = 26, xl = 32;
}
