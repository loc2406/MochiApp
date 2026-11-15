import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/learning/learning_models.dart';
import 'package:mochi_app/core/learning/review_policy.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/features/flashcards/review_screen.dart';

import 'account_sync_test.dart';

Map<String, dynamic> draft() => {
  'cardIds': ['c'],
  'durationMinutes': 5,
  'reason': 'Thẻ đến hạn, cần kiểm tra điều kiện áp dụng.',
  'quiz': {
    'topic': 'Công sai',
    'questions': [
      {
        'id': 1,
        'sourceCardId': 'c',
        'question': 'Dãy 2, 5, 8 có công sai là gì?',
        'options': ['A. 1', 'B. 3', 'C. 5', 'D. 8'],
        'correctAnswer': 'B',
        'explanation': 'Hiệu hai số hạng liên tiếp là 3.',
      },
    ],
  },
};
MochiStore makeStore() =>
    MochiStore(
        cloudService: FakeCloud(),
        aiService: AIService(
          client: MockClient((r) async {
            final body = jsonDecode(r.body);
            expect(body['messages'][1]['content'], contains('dueCards'));
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'choices': [
                    {
                      'finish_reason': 'stop',
                      'message': {'content': jsonEncode(draft())},
                    },
                  ],
                }),
              ),
              200,
            );
          }),
        ),
      )
      ..isLoaded = true
      ..isFirstTime = false
      ..dailyRoutine = const DailyRoutine(
        eveningFreeStart: '00:01',
        eveningFreeEnd: '23:59',
        preferredDailyMinutes: 45,
      )
      ..decks = [
        FlashcardDeck(
          id: 'd',
          title: 'Cấp số cộng',
          subject: 'Toán',
          topicIds: ['topic'],
        ),
      ]
      ..flashcards = [
        FlashcardItem(
          id: 'c',
          deckId: 'd',
          front: 'Công sai là gì?',
          back: 'Công sai là hiệu giữa hai số hạng liên tiếp trong một cấp số cộng. Ví dụ dãy hai, năm, tám có công sai bằng ba vì mỗi bước ta cộng thêm ba.',
          nextReviewAt: DateTime(2020),
        ),
      ];
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('due policy does not repeat remembered cards ahead of schedule or teach unstudied topics', () {
    final store = makeStore();
    final now = DateTime(2026, 11, 2, 10);
    store.flashcards.add(
      FlashcardItem(
        id: 'future',
        deckId: 'd',
        front: 'q',
        back: 'a',
        repetitions: 5,
        nextReviewAt: now.add(const Duration(days: 10)),
      ),
    );
    expect(
      ReviewPolicy.dueCards(
        now: now,
        cards: store.flashcards,
        decks: store.decks,
        learning: store.learning,
      ).map((c) => c.id),
      ['c'],
    );
    store.learning.progress = [
      TopicProgress(
        id: 'p',
        courseId: 'course',
        topicId: 'topic',
        readiness: TopicReadiness.notStudied,
        updatedAt: now,
      ),
    ];
    expect(
      ReviewPolicy.dueCards(
        now: now,
        cards: store.flashcards,
        decks: store.decks,
        learning: store.learning,
      ),
      isEmpty,
    );
    store.dispose();
  });
  test('invalid source ids and excess budget are rejected', () {
    final store = makeStore();
    final d = draft();
    d['quiz']['questions'][0]['sourceCardId'] = 'invented';
    expect(
      () => ReviewPolicy.validateDraft(d, store.flashcards, 10),
      throwsFormatException,
    );
    expect(
      () => ReviewPolicy.validateDraft(draft(), store.flashcards, 2),
      throwsFormatException,
    );
    store.dispose();
  });
  test('session persists schedule, requires cards before quiz, idempotent ratings, wrong answer brings review closer', () async {
    final store = makeStore();
    final id = await store.createReviewSession(
      draft(),
      at: DateTime(2026, 11, 2, 10),
    );
    expect(store.tasks.single.id, id);
    expect(store.tasks.single.scheduledTime, isNotNull);
    await expectLater(store.answerReviewQuiz(id, 0, 0), throwsStateError);
    await store.gradeReviewCard(id, 'c', 3);
    final stars = store.stars;
    await store.gradeReviewCard(id, 'c', 0);
    expect(store.stars, stars);
    await store.answerReviewQuiz(id, 0, 0);
    expect(store.learning.reviewSessions.single['status'], 'completed');
    expect(store.flashcards.single.repetitions, 0);
    expect(store.tasks.single.isDone, isTrue);
    final restored = LearningState.fromJson(store.learning.toJson());
    expect(
      restored.reviewSessions.single['quiz']['answers']['0']['optionIndex'],
      0,
    );
    store.dispose();
  });
  test(
    'editing knowledge invalidates stale session and returns card to due queue',
    () async {
      final store = makeStore();
      await store.createReviewSession(draft(), at: DateTime(2026, 11, 2, 10));
      await store.editKnowledgeCard('c', 'Câu hỏi mới', 'Nội dung mới');
      expect(store.learning.reviewSessions.single['status'], 'invalidated');
      expect(store.tasks, isEmpty);
      expect(store.flashcards.single.front, 'Câu hỏi mới');
      store.dispose();
    },
  );
  for (final width in [320.0, 1366.0]) {
    testWidgets(
      'automatic revision opens cards then quiz then management at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = makeStore();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: store,
            child: const MaterialApp(home: ReviewScreen(active: true)),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.text('Công sai là gì?'), findsWidgets);
        await tester.ensureVisible(find.text('Xem giải thích'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xem giải thích'));
        await tester.pump();
        await tester.ensureVisible(find.text('Nhớ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhớ'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.text('Kiểm tra khả năng vận dụng'), findsOneWidget);
        final answer = find.byKey(const ValueKey('quiz-option-0-1'));
        await tester.ensureVisible(answer);
        await tester.pumpAndSettle();
        await tester.tap(answer);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.text('Đã hoàn thành lượt ôn'), findsOneWidget);
        expect(find.text('Đến Quản lý kiến thức'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
}
