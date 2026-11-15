/// Checks structure; academic correctness still needs independent evaluation.
Map<String, dynamic> validateTutorQuiz(dynamic value) {
  if (value is! Map ||
      value['topic'] is! String ||
      (value['topic'] as String).trim().isEmpty ||
      value['questions'] is! List) {
    throw const FormatException('Quiz chưa có cấu trúc hợp lệ.');
  }
  final questions = value['questions'] as List;
  if (questions.isEmpty || questions.length > 10) {
    throw const FormatException('Quiz cần từ 1 đến 10 câu.');
  }
  for (final q in questions) {
    if (q is! Map ||
        q['question'] is! String ||
        (q['question'] as String).trim().isEmpty ||
        q['explanation'] is! String ||
        (q['explanation'] as String).trim().isEmpty ||
        q['options'] is! List ||
        (q['options'] as List).length != 4 ||
        !(q['options'] as List).every(
          (o) => o is String && o.trim().isNotEmpty,
        ) ||
        (q['options'] as List).toSet().length != 4 ||
        !['A', 'B', 'C', 'D'].contains(q['correctAnswer'])) {
      throw const FormatException('Câu hỏi, lựa chọn hoặc đáp án chưa hợp lệ.');
    }
  }
  return Map<String, dynamic>.from(value);
}
