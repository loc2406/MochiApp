import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mochi_app/core/services/ai_gateway_client.dart';

void main() {
  test('no anonymous provider request or embedded API secret', () async {
    var called = false;
    final client = AIGatewayClient(
      token: () => null,
      inner: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        body: '{}',
      ),
      throwsA(isA<AIAuthenticationRequired>()),
    );
    expect(called, false);
  });
  test('forwards authenticated request to gateway, not provider, and preserves UTF8', () async {
    final client = AIGatewayClient(
      token: () => 'user-session',
      inner: MockClient((r) async {
        expect(r.url.toString(), '${AIGatewayClient.baseUrl}/chat/completions');
        expect(r.headers['Authorization'], 'Bearer user-session');
        expect(jsonDecode(r.body)['question'], 'Vì sao cần ôn bài?');
        return http.Response('{}', 200);
      }),
    );
    await client.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer must-not-leave-client',
      },
      body: jsonEncode({'question': 'Vì sao cần ôn bài?'}),
    );
  });
}
