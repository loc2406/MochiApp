import 'package:flutter/material.dart';

/// Type scale for the Mochi design language. The family is always the bundled
/// Inter; sizes follow the reference art direction (generous headings, calm
/// body copy) and never clamp the user's text scale.
abstract final class MochiType {
  static const String family = 'Inter';

  static TextTheme textTheme(Color ink, Color muted) => TextTheme(
    displayLarge: TextStyle(
      fontFamily: family,
      fontSize: 34,
      height: 1.12,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      color: ink,
    ),
    displayMedium: TextStyle(
      fontFamily: family,
      fontSize: 30,
      height: 1.14,
      fontWeight: FontWeight.w800,
      letterSpacing: -.9,
      color: ink,
    ),
    displaySmall: pageTitle(ink),
    headlineLarge: TextStyle(
      fontFamily: family,
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -.6,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontFamily: family,
      fontSize: 21,
      height: 1.22,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
      color: ink,
    ),
    headlineSmall: TextStyle(
      fontFamily: family,
      fontSize: 18,
      height: 1.26,
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontFamily: family,
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontFamily: family,
      fontSize: 15.5,
      height: 1.32,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleSmall: TextStyle(
      fontFamily: family,
      fontSize: 14,
      height: 1.34,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(
      fontFamily: family,
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: family,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: ink,
    ),
    bodySmall: TextStyle(
      fontFamily: family,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: muted,
    ),
    labelLarge: TextStyle(
      fontFamily: family,
      fontSize: 13.5,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    labelMedium: TextStyle(
      fontFamily: family,
      fontSize: 12.5,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: muted,
    ),
    labelSmall: TextStyle(
      fontFamily: family,
      fontSize: 11.5,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: muted,
    ),
  );

  static TextStyle pageTitle(Color ink) => TextStyle(
    fontFamily: family,
    fontSize: 27,
    height: 1.16,
    fontWeight: FontWeight.w800,
    letterSpacing: -.7,
    color: ink,
  );

  static TextStyle section(Color ink) => TextStyle(
    fontFamily: family,
    fontSize: 17.5,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -.3,
    color: ink,
  );

  static TextStyle button(Color color) => TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -.1,
    color: color,
  );
}
