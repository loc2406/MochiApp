import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/core/models/mochi_models.dart';

void main() {
  Future<Map<String, dynamic>> ask(
    AIService service, {
    List<ChatMessageModel> history = const [],
  }) => service.askTutor(
    question: 'Vì sao bước đó đúng?',
    subject: 'Toán',
    currentTaskTitle: 'Phương trình',
    gradeBand: 'THCS',
    learnerName: 'An',
    companionName: 'Buddy',
    learningGoal: 'Hiểu bản chất',
    history: history,
  );

  test(
    'Recent history, one current question, no welcome, profile context',
    () async {
      late Map<String, dynamic> sent;
      final client = MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 'verified-id',
            'model': AIService.primaryModel,
            'choices': [
              {
                'message': {'content': 'Vì hai vế cùng được trừ 3.'},
                'finish_reason': 'stop',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final history = [
        ChatMessageModel(id: 'welcome', role: 'assistant', content: 'welcome'),
        for (var i = 0; i < 18; i++)
          ChatMessageModel(
            id: '$i',
            role: i.isEven ? 'user' : 'assistant',
            content: 'turn $i',
          ),
        ChatMessageModel(
          id: 'current',
          role: 'user',
          content: 'Vì sao bước đó đúng?',
        ),
      ];
      final result = await ask(AIService(client: client), history: history);
      final messages = sent['messages'] as List;
      expect(messages.length, 14);
      expect(messages[1]['content'], 'turn 6');
      expect(messages[messages.length - 2]['content'], 'turn 17');
      expect(
        messages.where((m) => m['content'] == 'Vì sao bước đó đúng?').length,
        1,
      );
      expect(messages.first['content'], contains('Buddy'));
      expect(
        messages.first['content'],
        contains('Không bắt buộc kết thúc bằng câu hỏi'),
      );
      expect(jsonEncode(messages), isNot(contains('welcome')));
      expect(result['source'], 'groq_cloud');
      expect(result['requestId'], 'verified-id');
      expect(result['truncated'], false);
      expect(sent['max_completion_tokens'], 2200);
    },
  );

  test('Length finish reason is not presented as a complete answer', () async {
    final result = await ask(
      AIService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Phần còn dở'},
                  'finish_reason': 'length',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );
    expect(result['truncated'], true);
  });

  test(
    'Service failure is explicit, not a fake offline tutor answer',
    () async {
      var calls = 0;
      final result = await ask(
        AIService(
          client: MockClient((_) async {
            calls++;
            return http.Response('{}', 429);
          }),
        ),
      );
      // 429 là hạn mức: thử model thứ hai cũng vô ích nên chỉ gọi một lần.
      expect(calls, 1);
      expect(result['source'], 'unavailable');
      expect(result['reason'], 'capacity');
      expect(result['reply'], contains('hạn mức'));
    },
  );

  test('Gateway origin rejection is explained and not retried', () async {
    var calls = 0;
    final result = await ask(
      AIService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{"error":{"code":"origin_denied"}}', 403);
        }),
      ),
    );
    expect(calls, 1);
    expect(result['source'], 'unavailable');
    expect(result['reason'], 'origin_denied');
    expect(result['reply'], contains('ALLOWED_ORIGINS'));
  });

  test(
    'Malformed success response retries fallback and preserves provenance',
    () async {
      var calls = 0;
      final result = await ask(
        AIService(
          client: MockClient((r) async {
            calls++;
            if (calls == 1) return http.Response('{bad json', 200);
            expect(jsonDecode(r.body)['model'], AIService.fallbackModel);
            return http.Response(
              jsonEncode({
                'id': 'fallback-id',
                'model': AIService.fallbackModel,
                'choices': [
                  {
                    'message': {'content': 'Một ví dụ nhỏ.'},
                    'finish_reason': 'stop',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      expect(result['model'], AIService.fallbackModel);
      expect(result['source'], 'groq_cloud');
    },
  );
}
