import 'package:flutter/material.dart';

import '../../core/models/tutor_quiz.dart';
import '../../design/pastel/pastel_components.dart';
import '../../shared/widgets/ai_message_body.dart';

/// Review-specific presentation. Saving and validation use the existing quiz API.
class ReviewQuizCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(int questionIndex, int optionIndex) onAnswer;
  const ReviewQuizCard({super.key, required this.data, required this.onAnswer});
  @override
  State<ReviewQuizCard> createState() => _ReviewQuizCardState();
}

class _ReviewQuizCardState extends State<ReviewQuizCard> {
  int _index = 0;
  bool _saving = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    try {
      validateTutorQuiz(widget.data);
    } on FormatException {
      return const PastelNoticeBanner(
        message: 'Bộ câu hỏi chưa hợp lệ. Hãy yêu cầu Mochi tạo lại.',
        severity: PastelNoticeSeverity.warning,
      );
    }
    final p = PastelPalette.of(context);
    final questions = widget.data['questions'] as List;
    final q = questions[_index] as Map;
    final selected =
        ((widget.data['answers'] as Map?)?['$_index'] as Map?)?['optionIndex']
            as int?;
    final correct = ['A', 'B', 'C', 'D'].indexOf(q['correctAnswer']);
    return PastelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.data['topic'],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: PastelChip(
              label: 'Câu ${_index + 1}/${questions.length}',
              icon: Icons.quiz_outlined,
            ),
          ),
          const SizedBox(height: 16),
          AIMessageBody(text: q['question'], color: p.ink),
          const SizedBox(height: 16),
          for (var option = 0; option < 4; option++) ...[
            Builder(
              builder: (context) {
                final right = selected != null && option == correct;
                final wrong = selected == option && option != correct;
                final tone = right
                    ? (p.dark
                          ? const Color(0xFF8CE5C9)
                          : const Color(0xFF15715A))
                    : wrong
                    ? (p.dark
                          ? const Color(0xFFFFA6BB)
                          : const Color(0xFFAF2449))
                    : p.action;
                final text = (q['options'][option] as String).replaceFirst(
                  RegExp(r'^([A-Da-d])[.):]\s*'),
                  '',
                );
                return Semantics(
                  button: true,
                  selected: selected == option,
                  child: Material(
                    color: right || wrong
                        ? Color.lerp(p.surface, tone, .12)!
                        : p.soft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: right || wrong ? tone : p.border),
                    ),
                    child: InkWell(
                      key: ValueKey('quiz-option-$_index-$option'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: selected != null || _saving
                          ? null
                          : () async {
                              setState(() {
                                _saving = true;
                                _error = null;
                              });
                              try {
                                await widget.onAnswer(_index, option);
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () => _error = 'Chưa lưu được câu trả lời. Thử lại nhé.',
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _saving = false);
                                }
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                String.fromCharCode(65 + option),
                                style: TextStyle(
                                  color: tone,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AIMessageBody(text: text, color: p.ink),
                            ),
                            if (right)
                              Icon(
                                Icons.check_circle_rounded,
                                color: tone,
                                size: 20,
                              ),
                            if (wrong)
                              Icon(
                                Icons.cancel_outlined,
                                color: tone,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          if (_saving) const LinearProgressIndicator(),
          if (_error != null)
            PastelNoticeBanner(
              message: _error!,
              severity: PastelNoticeSeverity.error,
            ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            PastelNoticeBanner(
              message: selected == correct
                  ? 'Đúng rồi.'
                  : 'Chưa đúng. Đáp án: ${q['correctAnswer']}.',
              severity: selected == correct
                  ? PastelNoticeSeverity.success
                  : PastelNoticeSeverity.warning,
              compact: true,
            ),
            const SizedBox(height: 12),
            AIMessageBody(text: q['explanation'], color: p.ink),
            const SizedBox(height: 8),
            Text(
              'Đáp án do AI tạo và chưa được xác minh độc lập. Hãy kiểm chứng với SGK hoặc giáo viên; kết quả này không xác nhận đã vững cả chủ đề.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_index > 0)
                PastelButton(
                  label: 'Câu trước',
                  variant: PastelButtonVariant.secondary,
                  onPressed: _saving ? null : () => setState(() => _index--),
                ),
              if (_index + 1 < questions.length)
                PastelButton(
                  label: 'Câu tiếp',
                  onPressed: selected == null || _saving
                      ? null
                      : () => setState(() => _index++),
                ),
              if (_index + 1 == questions.length && selected != null)
                Text(
                  'Đã hoàn thành lượt quiz.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
