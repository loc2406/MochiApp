import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/design/pastel/pastel_theme.dart';
import 'package:mochi_app/design/theme/mochi_presets.dart';

void main() {
  test('pastel text stays readable across accents, backgrounds and modes', () {
    for (final dark in [false, true]) {
      for (final accent in MochiPresets.colors.values) {
        final p = PastelPalette.create(accent, dark, false);
        for (final background in [p.surface, p.soft]) {
          expect(
            PastelPalette.contrast(p.ink, background),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            PastelPalette.contrast(p.muted, background),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            PastelPalette.contrast(p.action, background),
            greaterThanOrEqualTo(4.5),
          );
        }
        for (final stop in p.primary.colors) {
          expect(
            PastelPalette.contrast(p.onAction, stop),
            greaterThanOrEqualTo(4.5),
          );
        }
        for (final key in PastelBackgrounds.labels.keys) {
          for (final background in PastelBackgrounds.colors(key, dark)) {
            expect(
              PastelPalette.contrast(p.ink, background),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
      }
    }
  });
  test(
    'background persists independently and old profiles retain a default',
    () {
      final profile = ProfileModel.fromJson({'name': 'An'});
      expect(profile.backgroundPreset, 'lavender');
      profile.backgroundPreset = 'mint';
      profile.themePreset = 'cyberAmber';
      final restored = ProfileModel.fromJson(profile.toJson());
      expect(restored.backgroundPreset, 'mint');
      expect(restored.themePreset, 'cyberAmber');
      expect(
        PastelBackgrounds.colors('unknown', false),
        PastelBackgrounds.colors('lavender', false),
      );
      expect(
        PastelTheme.build(
          accent: Colors.purple,
          brightness: Brightness.dark,
        ).textTheme.bodyMedium?.fontFamily,
        'Inter',
      );
    },
  );
}
