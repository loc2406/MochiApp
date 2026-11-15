import 'package:flutter/material.dart';

import '../../shared/widgets/ai_message_body.dart';

/// Lead with meaning; equations and symbol glossaries are optional detail.
class KnowledgeExplanation extends StatelessWidget {
  final String text;
  final Color? color;
  const KnowledgeExplanation({super.key, required this.text, this.color});
  @override
  Widget build(BuildContext context) {
    final math = RegExp(r'\$|\\\(|\\\[').firstMatch(text);
    if (math == null || math.start < 40)
      return AIMessageBody(text: text, color: color);
    final summary = text.substring(0, math.start).trim();
    final exampleIndex = text.indexOf('Ví dụ:');
    final example = exampleIndex >= math.start
        ? text.substring(exampleIndex)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hiểu đơn giản',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        AIMessageBody(text: summary, color: color),
        if (example != null) ...[
          const SizedBox(height: 12),
          AIMessageBody(text: example, color: color),
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Công thức, ký hiệu và điều kiện'),
          children: [
            AIMessageBody(
              color: color,
              text: text.substring(
                math.start,
                exampleIndex > math.start ? exampleIndex : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
