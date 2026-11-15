import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveSessionImport {
  final String id;
  final String text;
  final bool complete;
  final String source;
  const LiveSessionImport({
    required this.id,
    required this.text,
    required this.complete,
    required this.source,
  });
  factory LiveSessionImport.parse(String raw) {
    if (raw.length > 100000 || raw.trim().isEmpty)
      throw const FormatException('Nội dung phiên không hợp lệ');
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['schema'] == 'mochi.live.v1') {
        final messages = data['messages'];
        if (messages is! List || messages.isEmpty)
          throw const FormatException('Phiên chưa có lời thoại');
        final text = messages
            .map((m) {
              if (m is! Map ||
                  m['content'] is! String ||
                  !['user', 'assistant'].contains(m['role'])) {
                throw const FormatException('Lời thoại không hợp lệ');
              }
              return '${m['role'] == 'user' ? 'Người học' : 'Trợ lý'}: ${m['content']}';
            })
            .join('\n\n');
        return LiveSessionImport(
          id: data['id'].toString(),
          text: text,
          complete: data['complete'] == true,
          source: 'Phiên học trực tiếp',
        );
      }
    } on FormatException {
      if (raw.trimLeft().startsWith('{')) rethrow;
    }
    if (RegExp(r'^https?://\S+$').hasMatch(raw.trim())) {
      throw const FormatException(
        'Đây chỉ là đường dẫn, chưa phải nội dung phiên. Hãy chia sẻ hoặc dán lời thoại.',
      );
    }
    return LiveSessionImport(
      id: 'shared_${DateTime.now().microsecondsSinceEpoch}',
      text: raw.trim(),
      complete: false,
      source: 'Nội dung được chia sẻ',
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'complete': complete,
    'source': source,
    'savedAt': DateTime.now().toIso8601String(),
  };
}

class LiveBridgeService {
  static const channel = MethodChannel('mochi/live_bridge');
  static Future<void> openGemini() async => channel.invokeMethod('openGemini');
  static Future<String?> takePending() =>
      channel.invokeMethod<String>('takePending');
  static Future<void> save(LiveSessionImport session) async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        jsonDecode(prefs.getString('mochi_live_sessions_v1') ?? '[]') as List;
    if (!list.any((e) => e['id'] == session.id)) list.add(session.toJson());
    await prefs.setString('mochi_live_sessions_v1', jsonEncode(list));
  }
}
