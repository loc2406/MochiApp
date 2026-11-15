import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/core/models/mochi_models.dart';

void main() {
  test(
    'Live tutor tone, maths, recent context',
    () async {
      final service = AIService();
      final history = <ChatMessageModel>[];
      final evidence = <Map<String, dynamic>>[];
      for (final question in [
        'Mình học mãi vẫn không hiểu phương trình, hơi nản.',
        'Giải thích giúp mình 2x + 3 = 7, ngắn thôi nhé.',
        'Vì sao lại trừ 3 ở cả hai vế?',
      ]) {
        final result = await service.askTutor(
          question: question,
          subject: 'Toán',
          currentTaskTitle: 'Phương trình bậc nhất',
          gradeBand: 'THCS',
          companionName: 'Buddy',
          learningGoal: 'Hiểu thay vì học thuộc',
          history: history,
        );
        expect(result['source'], 'groq_cloud');
        expect(result['truncated'], false);
        expect((result['reply'] as String).trim(), isNotEmpty);
        evidence.add({'question': question, ...result}..remove('emotion'));
        history.add(
          ChatMessageModel(
            id: 'u${history.length}',
            role: 'user',
            content: question,
          ),
        );
        history.add(
          ChatMessageModel(
            id: 'a${history.length}',
            role: 'assistant',
            content: result['reply'],
          ),
        );
      }
      File(
        '/home/ben/mochi_delivery/ai-fix/live-responses.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(evidence));
    },
    skip: !const bool.fromEnvironment('LIVE_AI'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
