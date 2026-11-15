import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mochi_app/core/services/ai_service.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();
    final req = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = bodyBytes;
    final res = await handler(req);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  test('extractTimetable parses valid JSON from model response', () async {
    final client = MockHttpClient((req) async {
      final jsonStr = jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode([
                {'subject': 'Toán', 'weekday': 1, 'startTime': '07:15', 'endTime': '08:00'},
                {'subject': 'Văn', 'weekday': 1, 'startTime': '08:05', 'endTime': '08:50'},
              ]),
            },
          },
        ],
      });
      return http.Response.bytes(
        utf8.encode(jsonStr),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final ai = AIService(client: client);
    final res = await ai.extractTimetable(rawContent: 'Thứ 2: Tiết 1 Toán, Tiết 2 Văn');
    expect(res.length, 2);
    expect(res.first['subject'], 'Toán');
    expect(res.first['weekday'], 1);
    expect(res.first['startTime'], '07:15');
  });

  test('generateQuiz returns valid question structure', () async {
    final client = MockHttpClient((req) async {
      final jsonStr = jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode({
                'topic': 'Cấp số cộng',
                'questions': [
                  {
                    'id': 1,
                    'question': 'Công thức số hạng tổng quát của cấp số cộng?',
                    'options': ['A. un = u1 + (n-1)d', 'B. un = u1 * d', 'C. un = u1 + nd', 'D. un = d'],
                    'correctAnswer': 'A',
                    'explanation': 'Theo định nghĩa cấp số cộng.',
                  },
                ],
              }),
            },
          },
        ],
      });
      return http.Response.bytes(
        utf8.encode(jsonStr),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final ai = AIService(client: client);
    final quiz = await ai.generateQuiz(topic: 'Cấp số cộng', subject: 'Toán', count: 1);
    expect(quiz['topic'], 'Cấp số cộng');
    expect(quiz['questions'], isA<List>());
    expect((quiz['questions'] as List).first['correctAnswer'], 'A');
  });

  test('parseScheduleAction detects reschedule request', () async {
    final client = MockHttpClient((req) async {
      final jsonStr = jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode({
                'action': 'reschedule_task',
                'taskTitle': 'Bài tập Toán',
                'subject': 'Toán',
                'newTime': '20:30',
                'reason': 'Bận việc nhà',
              }),
            },
          },
        ],
      });
      return http.Response.bytes(
        utf8.encode(jsonStr),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final ai = AIService(client: client);
    final action = await ai.parseScheduleAction('Tối nay mình bận, dời bài tập Toán sang 20:30');
    expect(action, isNotNull);
    expect(action!['action'], 'reschedule_task');
    expect(action['newTime'], '20:30');
  });
}
