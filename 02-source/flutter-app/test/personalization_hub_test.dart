import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/design/theme/mochi_presets.dart';
import 'package:mochi_app/core/services/tutor_prompt.dart';

void main() {
  group('Personalization Hub Acceptance', () {
    test(
      'ProfileModel defaults and serialization preserve all OS27 preferences',
      () {
        final profile = ProfileModel(
          name: 'Thành Lộc',
          robotName: 'Unicorn :vv',
          themePreset: 'neonEmerald',
          tutorPersona: 'strict',
          tutorDetailLevel: 'concise',
          glassOpacity: 0.75,
          highContrast: true,
        );

        final json = profile.toJson();
        expect(json['themePreset'], 'neonEmerald');
        expect(json['tutorPersona'], 'strict');
        expect(json['tutorDetailLevel'], 'concise');
        expect(json['glassOpacity'], 0.75);
        expect(json['highContrast'], true);

        final restored = ProfileModel.fromJson(json);
        expect(restored.themePreset, 'neonEmerald');
        expect(restored.tutorPersona, 'strict');
        expect(restored.tutorDetailLevel, 'concise');
        expect(restored.glassOpacity, 0.75);
        expect(restored.highContrast, true);
      },
    );

    test(
      'MochiPresets returns correct colors for all 6 presets with fallback',
      () {
        expect(
          MochiPresets.accentFor('electricViolet'),
          MochiPresets.electricViolet,
        );
        expect(
          MochiPresets.accentFor('cupertinoBlue'),
          MochiPresets.cupertinoBlue,
        );
        expect(MochiPresets.accentFor('neonEmerald'), MochiPresets.neonEmerald);
        expect(MochiPresets.accentFor('cyberAmber'), MochiPresets.cyberAmber);
        expect(MochiPresets.accentFor('sunsetCoral'), MochiPresets.sunsetCoral);
        expect(MochiPresets.accentFor('oceanCyan'), MochiPresets.oceanCyan);
        expect(
          MochiPresets.accentFor('unknown_key'),
          MochiPresets.electricViolet,
        );
      },
    );

    test('TutorPrompt enforces strict persona allowlist and detail level', () {
      final promptFriendly = TutorPrompt.build(
        subject: 'Toán',
        task: 'Đại số',
        grade: 'Lớp 11',
        persona: 'friendly',
        detailLevel: 'step_by_step',
      );
      expect(
        promptFriendly,
        contains('Thân thiện, gần gũi như bạn học cùng bàn'),
      );
      expect(promptFriendly, contains('Giải thích từng bước rõ ràng'));

      final promptStrict = TutorPrompt.build(
        subject: 'Toán',
        task: 'Đại số',
        grade: 'Lớp 11',
        persona: 'strict',
        detailLevel: 'concise',
      );
      expect(promptStrict, contains('Chuẩn mực, học thuật nghiêm túc'));
      expect(promptStrict, contains('Trả lời cô đọng, súc tích'));

      final promptInjected = TutorPrompt.build(
        subject: 'Toán',
        task: 'Đại số',
        grade: 'Lớp 11',
        persona: 'malicious_injection; drop table',
      );
      expect(promptInjected, contains('Thân thiện, gần gũi'));
    });
  });
}
