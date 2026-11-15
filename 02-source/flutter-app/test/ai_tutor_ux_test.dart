import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/features/ai_tutor/ai_tutor_screen.dart';
import 'package:mochi_app/shared/widgets/ai_message_body.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(MochiStore store, Widget child) {
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Guest reply shows a login CTA that switches to the profile tab',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MochiStore();
      var requestedLogin = false;
      await tester.pumpWidget(
        _wrap(
          store,
          AITutorScreen(onRequestLogin: () => requestedLogin = true),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Giải thích giúp mình');
      await tester.tap(find.byTooltip('Gửi câu hỏi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Đăng nhập ngay'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Đăng nhập ngay'));
      await tester.pump();
      expect(requestedLogin, isTrue);

      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('Truncated reply explains the cut and offers a continuation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MochiStore(
      aiService: AIService(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'id': 'truncated-test',
                'choices': [
                  {
                    'message': {'content': 'Một nửa câu trả lời'},
                    'finish_reason': 'length',
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );

    await tester.pumpWidget(_wrap(store, const AITutorScreen(inSheet: true)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Hỏi dài');
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.textContaining('có thể bị cắt'), findsOneWidget);
    expect(find.text('Viết tiếp'), findsOneWidget);
    expect(find.textContaining('AI có thể sai'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('Cancel stops the waiting state and ignores a late reply', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MochiStore(
      aiService: AIService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'id': 'late',
                'choices': [
                  {
                    'message': {'content': 'Phản hồi về muộn'},
                    'finish_reason': 'stop',
                  },
                ],
              }),
            ),
            200,
          );
        }),
      ),
    );

    await tester.pumpWidget(_wrap(store, const AITutorScreen(inSheet: true)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Câu hỏi chậm');
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Huỷ'), findsOneWidget);
    await tester.tap(find.text('Huỷ'));
    await tester.pump();
    expect(find.text('Huỷ'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Phản hồi về muộn'), findsNothing);
    // Chỉ còn tin nhắn chào mừng.
    expect(find.byType(AIMessageBody), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  Future<MochiStore> pumpFailedTutor(
    WidgetTester tester,
    int status,
    String body,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MochiStore(
      aiService: AIService(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(body),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );
    await tester.pumpWidget(_wrap(store, const AITutorScreen(inSheet: true)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Giải thích giúp mình');
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    return store;
  }

  testWidgets('Origin rejection is explained and retry is not offered', (
    tester,
  ) async {
    final store = await pumpFailedTutor(
      tester,
      403,
      '{"error":{"code":"origin_denied"}}',
    );
    expect(find.textContaining('ALLOWED_ORIGINS'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('Expired session offers a fresh login instead of retry', (
    tester,
  ) async {
    final store = await pumpFailedTutor(
      tester,
      401,
      '{"error":{"code":"session_expired"}}',
    );
    expect(find.textContaining('Phiên đăng nhập đã hết hạn'), findsOneWidget);
    expect(find.text('Đăng nhập lại'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
