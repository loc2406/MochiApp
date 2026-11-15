import 'package:flutter/material.dart';

/// Accent presets offered in Settings. The keys match the values stored in the
/// profile, so switching a preset never migrates data.
abstract final class MochiPresets {
  static const Color lightViolet = Color(0xFFc9cffa);
  static const Color violet = Color(0xFF7C3AED);
  static const Color lightBlue = Color(0xFFa0dbfa);
  static const Color blue = Color(0xFF2563EB);
  static const Color neonEmerald = Color(0xFF10B981);
  static const Color orange = Color(0xFFf2c9c9);
  static const Color cyberAmber = Color(0xFFF59E0B);
  static const Color sunsetCoral = Color(0xFFF43F5E);
  static const Color oceanCyan = Color(0xFF06B6D4);
  static const Color lightPink = Color(0xFFf2bbc9);
  static const Color pink = Color(0xFFf2a7ca);

  static const Map<String, Color> colors = {
    'lightViolet': lightViolet,
    'violet': violet,
    'lightBlue': lightBlue,
    'blue': blue,
    'oceanCyan': oceanCyan,
    'neonEmerald': neonEmerald,
    'orange': orange,
    'cyberAmber': cyberAmber,
    'sunsetCoral': sunsetCoral,
    'lightPink': lightPink,
    'pink': pink,
  };

  static const Map<String, String> labels = {
    'lightViolet': 'Tím nhạt',
    'violet': 'Tím',
    'lightBlue': 'Xanh nhạt',
    'blue': 'Xanh',
    'oceanCyan': 'Xanh biển',
    'neonEmerald': 'Xanh lá',
    'orange': 'Cam hồng',
    'cyberAmber': 'Vàng cam',
    'sunsetCoral': 'Hồng san hô',
    'lightPink': 'Hồng nhạt',
    'pink': 'Hồng',
  };

  static const String defaultKey = 'oceanCyan';

  static Color accentFor(String? key) => colors[key] ?? colors[defaultKey]!;

  static String labelFor(String? key) => labels[key] ?? labels[defaultKey]!;
}
