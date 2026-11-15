import 'package:flutter/material.dart';

import '../../../design/mochi_design.dart';
import '../../../shared/widgets/ai_message_body.dart';
import '../../../core/models/tutor_quiz.dart';

class TutorQuizCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(int questionIndex, int optionIndex) onAnswer;
  const TutorQuizCard({super.key, required this.data, required this.onAnswer});
  @override
  State<TutorQuizCard> createState() => _TutorQuizCardState();
}

class _TutorQuizCardState extends State<TutorQuizCard> {
  int _index = 0;
  bool _saving = false;
  String? _error;

  /// Options arrive as "A. 1"; keep the letter in the badge, not twice.
  static final _prefix = RegExp(r'^([A-Da-d])[.):]\s*');

  static String? _letterFor(Object? option) {
    final match = _prefix.firstMatch(option?.toString() ?? '');
    return match?.group(1)?.toUpperCase();
  }

  static String _optionText(Object? option) {
    final text = option?.toString() ?? '';
    return _prefix.hasMatch(text) ? text.replaceFirst(_prefix, '') : text;
  }

  @override
  Widget build(BuildContext context) {
    try {
      validateTutorQuiz(widget.data);
    } on FormatException {
      return Text('Bộ câu hỏi chưa hợp lệ. Hãy yêu cầu Mochi tạo lại.');
    }
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final questions = widget.data['questions'] as List;
    final question = questions[_index] as Map;
    final answers = widget.data['answers'] as Map? ?? {};
    final selected = (answers['$_index'] as Map?)?['optionIndex'] as int?;
    final correct = ['A', 'B', 'C', 'D'].indexOf(question['correctAnswer']);

    return MochiCard(
      margin: EdgeInsets.only(top: MochiSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.data['topic'],
            style: theme.textTheme.titleSmall?.copyWith(color: palette.ink),
          ),
          SizedBox(height: MochiSpacing.xs),
          Row(
            children: [
              MochiChip(
                label: 'Câu ${_index + 1}/${questions.length}',
                icon: Icons.quiz_outlined,
                tone: MochiChipTone.accent,
                compact: true,
              ),
            ],
          ),
          SizedBox(height: MochiSpacing.sm),
          AIMessageBody(text: question['question']),
          SizedBox(height: MochiSpacing.sm),
          for (var option = 0; option < 4; option++)
            Padding(
              padding: EdgeInsets.only(bottom: MochiSpacing.xs),
              child: _QuizOption(
                key: ValueKey('quiz-option-$_index-$option'),
                label: _letterFor((question['options'] as List)[option]),
                text: _optionText((question['options'] as List)[option]),
                selected: selected == option,
                isCorrect: selected != null && option == correct,
                showResult: selected != null,
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
                          if (mounted)
                            setState(
                              () => _error =
                                  'Chưa lưu được câu trả lời. Thử lại nhé.',
                            );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
              ),
            ),
          if (_saving)
            MochiProgressBar(value: 0, label: 'Đang lưu câu trả lời…'),
          if (_error != null) ...[
            MochiNoticeBanner(
              message: _error!,
              severity: MochiNoticeSeverity.error,
              compact: true,
            ),
            SizedBox(height: MochiSpacing.xs),
          ],
          if (selected != null) ...[
            MochiNoticeBanner(
              message: selected == correct
                  ? 'Đúng rồi.'
                  : 'Chưa đúng. Đáp án: ${question['correctAnswer']}.',
              severity: selected == correct
                  ? MochiNoticeSeverity.success
                  : MochiNoticeSeverity.warning,
              compact: true,
            ),
            SizedBox(height: MochiSpacing.xs),
            AIMessageBody(text: question['explanation']),
            SizedBox(height: MochiSpacing.xs),
            Text(
              'Đáp án do AI tạo và chưa được xác minh độc lập. Hãy kiểm chứng với SGK hoặc giáo viên; kết quả này không xác nhận đã vững cả chủ đề.',
              style: theme.textTheme.labelSmall?.copyWith(color: palette.muted),
            ),
          ],
          SizedBox(height: MochiSpacing.sm),
          Wrap(
            spacing: MochiSpacing.xs,
            runSpacing: MochiSpacing.xs,
            children: [
              if (_index > 0)
                TextButton(
                  onPressed: _saving ? null : () => setState(() => _index--),
                  child: Text('Câu trước'),
                ),
              if (_index + 1 < questions.length)
                MochiPrimaryButton(
                  onPressed: selected == null || _saving
                      ? null
                      : () => setState(() => _index++),
                  child: Text('Câu tiếp'),
                ),
              if (_index + 1 == questions.length && selected != null)
                Padding(
                  padding: EdgeInsets.only(top: MochiSpacing.xxs),
                  child: Text(
                    'Đã hoàn thành lượt quiz.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One answer row: soft card, letter badge, accent ring when picked.
class _QuizOption extends StatelessWidget {
  final String? label;
  final String text;
  final bool selected;
  final bool isCorrect;
  final bool showResult;
  final VoidCallback? onTap;

  const _QuizOption({
    super.key,
    required this.label,
    required this.text,
    required this.selected,
    required this.isCorrect,
    required this.showResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final highlight = selected || (showResult && isCorrect);
    final Color background;
    final Color border;
    if (showResult && selected) {
      background = isCorrect ? palette.successSoft : palette.dangerSoft;
      border = (isCorrect ? palette.success : palette.danger).withValues(
        alpha: .5,
      );
    } else if (showResult && isCorrect) {
      background = palette.successSoft;
      border = palette.success.withValues(alpha: .35);
    } else if (highlight) {
      background = palette.softAccent;
      border = palette.accentBorder;
    } else {
      background = palette.cardSoft;
      border = palette.cardBorder;
    }

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(MochiRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MochiRadius.control),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: MochiSpacing.sm,
              vertical: MochiSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MochiRadius.control),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: highlight ? palette.accent : palette.card,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      label!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: highlight ? palette.onAccent : palette.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: MochiSpacing.sm),
                ],
                Expanded(child: AIMessageBody(text: text)),
                if (showResult && isCorrect)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: palette.success,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
