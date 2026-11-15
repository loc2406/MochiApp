import 'ai_gateway_client.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_service.dart';
import 'smart_reminder_policy.dart';

class ReminderCopyWriter {
  final http.Client? client;
  ReminderCopyWriter({this.client});

  Future<ReminderCopy> generate(AIService ai) async {
    final ownedClient = client ?? AIGatewayClient();
    try {
      // Names, task titles and activity history stay local. Only generic
      // templates with placeholders are requested from the existing AI provider.
      final response = await ownedClient
          .post(
            Uri.parse(ai.customEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ai.apiKey}',
            },
            body: jsonEncode({
              'model': ai.modelName,
              'messages': [
                {
                  'role': 'system',
                  'content': 'Viết lời nhắc học tiếng Việt ấm áp, tôn trọng, không gây áp lực. Chỉ trả JSON với 4 khóa due, overdue, inactiveStudy, inactiveApp. Mỗi giá trị 1 câu tối đa 180 ký tự. due và overdue PHẢI có placeholder {task}; có thể dùng {name}. Không dùng emoji, markdown, đường dẫn, số ngày hoặc giờ cụ thể; không bịa thành tích, hình phạt hay khẳng định đã theo dõi trực tiếp. Đây là mẫu nội dung; quy tắc trên máy quyết định thời điểm.',
                },
                {
                  'role': 'user',
                  'content': 'due: đến lịch nhiệm vụ; overdue: nhiệm vụ vẫn chưa đánh dấu xong; inactiveStudy: lâu chưa ghi nhận học; inactiveApp: mời quay lại xem kế hoạch. Không trộn các tình huống.',
                },
              ],
              'temperature': 0.5,
              'max_completion_tokens': 1400,
              'reasoning_effort': 'low',
              'reasoning_format': 'parsed',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError('reminder_ai_unavailable');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['choices']?[0]?['finish_reason'] != 'stop') {
        throw const FormatException('Incomplete AI response');
      }
      var text = data['choices'][0]['message']['content'] as String;
      text = text
          .trim()
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
      return parse(text);
    } finally {
      if (client == null) ownedClient.close();
    }
  }

  static ReminderCopy parse(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('Expected object');
    final result = <String, String>{};
    for (final kind in ReminderKind.values) {
      final value = decoded[kind.name];
      if (value is! String ||
          value.trim().isEmpty ||
          value.length > 180 ||
          value.contains(RegExp(r'[\n\r<>]|https?://')) ||
          value.contains(
            RegExp(r'[\u{1F000}-\u{1FAFF}\u2600-\u27BF]', unicode: true),
          )) {
        throw const FormatException('Invalid reminder text');
      }
      final stripped = value.replaceAll('{name}', '').replaceAll('{task}', '');
      if (stripped.contains(RegExp(r'[{}]'))) {
        throw const FormatException('Unknown placeholder');
      }
      if ((kind == ReminderKind.due || kind == ReminderKind.overdue) &&
          !value.contains('{task}')) {
        throw const FormatException('Missing task placeholder');
      }
      if ((kind == ReminderKind.inactiveApp ||
              kind == ReminderKind.inactiveStudy) &&
          value.contains('{task}')) {
        throw const FormatException('Unexpected task placeholder');
      }
      result[kind.name] = value.trim();
    }
    return ReminderCopy(result, source: 'ai');
  }
}
