import 'account_sync_test.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/features/ai_tutor/ai_tutor_screen.dart';
import 'package:mochi_app/shared/widgets/ai_message_body.dart';

void main() {
  for (final viewport in [const Size(320, 700), const Size(640, 360)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Tutor send/receive $viewport scale=$scale', (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MochiStore(
          cloudService: FakeCloud(),
          aiService: AIService(
            client: MockClient(
              (_) async => http.Response.bytes(
                utf8.encode(
                  jsonEncode({
                    'id': 'screen-test',
                    'choices': [
                      {
                        'message': {
                          'content':
                              '**Kết quả** là '
                              r'$x=2$'
                              '.',
                        },
                        'finish_reason': 'stop',
                      },
                    ],
                  }),
                ),
                200,
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: store,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: viewport,
                  textScaler: TextScaler.linear(scale),
                ),
                child: const AITutorScreen(inSheet: true),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byType(TextField),
          'Giúp mình hiểu bài này',
        );
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byType(TextField),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.tap(find.byTooltip('Gửi câu hỏi'));
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byType(TextField),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isFalse,
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.textContaining('Học cùng'), findsOneWidget);
        expect(find.byType(AIMessageBody), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), 'Giải thích tiếp nhé');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byType(TextField),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isFalse,
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      });
    }
  }
}
