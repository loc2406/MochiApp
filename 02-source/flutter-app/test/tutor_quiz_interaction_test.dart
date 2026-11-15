import 'package:mochi_app/design/mochi_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/models/tutor_quiz.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/features/ai_tutor/widgets/tutor_quiz_card.dart';

import 'account_sync_test.dart';

Map<String, dynamic> quiz() => {
  'topic': 'Cấp số cộng',
  'questions': [
    for (var i = 0; i < 2; i++)
      {
        'id': i + 1,
        'question': 'Công sai của dãy 2, 5, 8 là bao nhiêu?',
        'options': ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
        'correctAnswer': 'C',
        'explanation': 'Giải thích: 5 − 2 = 3 và 8 − 5 = 3.',
      },
  ],
};
void main() {
  test('rejects malformed answers and repeated options', () {
    final q = quiz();
    (q['questions'] as List).first['correctAnswer'] = 'E';
    expect(() => validateTutorQuiz(q), throwsFormatException);
    expect(
      () => validateTutorQuiz({'topic': 'x', 'questions': []}),
      throwsFormatException,
    );
  });
  test('answer is persisted once without granting mastery/rewards', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MochiStore(cloudService: FakeCloud());
    final message = ChatMessageModel(
      id: 'quiz',
      role: 'assistant',
      content: 'Quiz',
      quizData: quiz(),
    );
    await store.recordTutorMessage(message);
    final before = store.learning.toJson();
    await store.answerTutorQuiz('quiz', 0, 2);
    await store.answerTutorQuiz('quiz', 0, 1);
    final restored = ChatMessageModel.fromJson(
      store.tutorMessages.single.toJson(),
    );
    expect(restored.quizData!['answers']['0']['optionIndex'], 2);
    expect(store.learning.toJson(), before);
    store.dispose();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'quiz hides answers until selection and unlocks next, scale=$scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var data = quiz();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 740),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (ctx, update) => TutorQuizCard(
                      data: data,
                      onAnswer: (q, o) async {
                        update(
                          () => data = {
                            ...data,
                            'answers': {
                              '$q': {'optionIndex': o},
                            },
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('Giải thích:'), findsNothing);
        final next = find.widgetWithText(MochiPrimaryButton, 'Câu tiếp');
        expect(tester.widget<MochiPrimaryButton>(next).onPressed, isNull);
        final option = find.byKey(const ValueKey('quiz-option-0-2'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pump();
        expect(tester.widget<MochiPrimaryButton>(next).onPressed, isNotNull);
        expect(find.text('Đúng rồi.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pump();
        expect(find.text('Câu 2/2'), findsOneWidget);
        expect(find.textContaining('Giải thích:'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
