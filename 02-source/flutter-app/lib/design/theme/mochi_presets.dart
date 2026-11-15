import 'package:flutter/material.dart';

/// Accent presets offered in Settings. The keys match the values stored in the
/// profile, so switching a preset never migrates data.
abstract final class MochiPresets {
  static const Color electricViolet = Color(0xFF7C3AED);
  static const Color cupertinoBlue = Color(0xFF2563EB);
  static const Color neonEmerald = Color(0xFF10B981);
  static const Color cyberAmber = Color(0xFFF59E0B);
  static const Color sunsetCoral = Color(0xFFF43F5E);
  static const Color oceanCyan = Color(0xFF06B6D4);

  static const Map<String, Color> colors = {
    'electricViolet': electricViolet,
    'cupertinoBlue': cupertinoBlue,
    'neonEmerald': neonEmerald,
    'cyberAmber': cyberAmber,
    'sunsetCoral': sunsetCoral,
    'oceanCyan': oceanCyan,
  };

  static const Map<String, String> labels = {
    'electricViolet': 'Tím điện',
    'cupertinoBlue': 'Xanh dương',
    'neonEmerald': 'Xanh ngọc',
    'cyberAmber': 'Hổ phách',
    'sunsetCoral': 'San hô',
    'oceanCyan': 'Xanh biển',
  };

  static const String defaultKey = 'electricViolet';

  static Color accentFor(String? key) => colors[key] ?? colors[defaultKey]!;

  static String labelFor(String? key) => labels[key] ?? labels[defaultKey]!;
}
