import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Live Groq call test', () async {
    final embeddedGroqKey = Platform.environment['GROQ_API_KEY'] ?? '';
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $embeddedGroqKey',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14)',
      },
      body: jsonEncode({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {'role': 'user', 'content': 'Test reply'},
        ],
      }),
    );
    print('Groq status: ${response.statusCode}');
    print('Groq body: ${response.body}');
    expect(response.statusCode, 200);
  });
}
