import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/models/student_share_sections.dart';

void main() {
  group('StudentShareSections.parse', () {
    test('enables every section when the field is missing or malformed', () {
      expect(StudentShareSections.parse(null), {...StudentShareSections.all});
      expect(StudentShareSections.parse('unexpected'), {
        ...StudentShareSections.all,
      });
    });

    test('keeps known keys and preserves an explicit empty selection', () {
      expect(StudentShareSections.parse(['goals', 'unknown', 42, 'xp']), {
        'goals',
        'xp',
      });
      expect(StudentShareSections.parse(const []), isEmpty);
    });
  });
}
