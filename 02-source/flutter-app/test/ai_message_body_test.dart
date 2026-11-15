import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:mochi_app/shared/widgets/ai_message_body.dart';

void main() {
  test(
    'Only markdown wrapper removed, actual code and operators preserved',
    () {
      expect(
        AIMessageBody.normalize('```markdown\n**Ví dụ**\n```'),
        '**Ví dụ**',
      );
      expect(
        AIMessageBody.normalize('```dart\nprint("a*b");\n```'),
        contains('```dart'),
      );
      expect(AIMessageBody.normalize(r'$x_1 + x_2$'), r'$x_1 + x_2$');
      expect(AIMessageBody.normalize('Giải thích x^2 bằng lời.'),
          'Giải thích x^2 bằng lời.');
    },
  );
  for (final width in [280.0, 360.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Markdown and math at width $width text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: AIMessageBody(
                      text: r'''### Hiểu bài
**Cùng thử nhé**, không cần vội.

1. Trừ 3 ở hai vế.
2. Ta có $x = 2$ và \(y = 3\).

$$
\frac{a}{b} + \sqrt{x^2 + y^2}
$$

```dart
final value = 2 * 3;
```

| Việc | Phút |
| --- | --- |
| Ôn bài | 15 |
''',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(Math), findsNWidgets(3));
        final spans = [
          ...tester
              .widgetList<RichText>(find.byType(RichText))
              .map((w) => w.text.toPlainText()),
          ...tester
              .widgetList<SelectableText>(find.byType(SelectableText))
              .map((w) => w.textSpan?.toPlainText() ?? w.data ?? ''),
        ].join(' ');
        expect(spans, contains('Hiểu bài'));
        expect(spans, isNot(contains('###')));
        expect(spans, isNot(contains('**')));
      });
    }
  }
  testWidgets('Invalid formula and long code do not crash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: AIMessageBody(
              text:
                  r'$\notAValidCommand{x}$'
                  '\n```text\n'
                  'averylongline_without_spaces_012345678901234567890123456789012345678901234567890123456789\n```',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
