import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/features/flashcards/review_screen.dart';
import 'package:mochi_app/features/flashcards/flashcards_screen.dart';

import 'account_sync_test.dart';
import 'review_journey_test.dart' show makeStore, draft;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'failed explanation keeps saved answer visible and allows rating',
    (tester) async {
      final seed = makeStore();
      final store =
          MochiStore(
              cloudService: FakeCloud(),
              aiService: AIService(
                client: MockClient(
                  (_) async => http.Response('Unavailable', 503),
                ),
              ),
            )
            ..dailyRoutine = seed.dailyRoutine
            ..decks = seed.decks
            ..flashcards = seed.flashcards;
      store.flashcards.single.back = 'd = 3';
      await store.createReviewSession(draft());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(home: ReviewScreen(active: true)),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Xem giải thích'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem giải thích'));
      await tester.pump();
      expect(find.textContaining('d = 3'), findsWidgets);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.text(
          'AI chưa bổ sung được giải thích. Bạn vẫn có thể ôn với nội dung đã lưu ở trên.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Nhớ'));
      await tester.ensureVisible(find.text('Nhớ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhớ'));
      await tester.pumpAndSettle();
      expect(store.learning.reviewSessions.single['grades']['c']['grade'], 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      seed.dispose();
    },
  );

  test(
    'offline session completes without quiz and survives serialization',
    () async {
      final store = makeStore();
      final id = await store.createReviewSession(
        {},
        offline: true,
        at: DateTime(2026, 11, 2, 10),
      );
      expect(
        store.learning.reviewSessions.single['quiz']['questions'],
        isEmpty,
      );
      await store.gradeReviewCard(id, 'c', 2);
      expect(store.learning.reviewSessions.single['status'], 'completed');
      expect(store.tasks.single.isDone, true);
      expect(store.learning.toJson()['reviewSessions'][0]['mode'], 'offline');
      store.dispose();
    },
  );

  test(
    'skip quiz preserves card schedule without recording an answer',
    () async {
      final store = makeStore();
      final id = await store.createReviewSession(
        draft(),
        at: DateTime(2026, 11, 2, 10),
      );
      await expectLater(store.skipReviewQuiz(id), throwsStateError);
      await store.gradeReviewCard(id, 'c', 3);
      final due = store.flashcards.single.nextReviewAt;
      await store.skipReviewQuiz(id);
      expect(store.learning.reviewSessions.single['quiz']['answers'], isEmpty);
      expect(store.learning.reviewSessions.single['quizSkipped'], true);
      expect(store.flashcards.single.nextReviewAt, due);
      expect(store.tasks.single.isDone, true);
      store.dispose();
    },
  );

  for (final deleted in [false, true]) {
    test(
      'remote ${deleted ? 'deletion' : 'edit'} invalidates session on second device',
      () async {
        final seed = makeStore();
        final cloud = FakeCloud();
        final first = MochiStore(cloudService: cloud);
        await first.init();
        first.dailyRoutine = seed.dailyRoutine;
        first.decks = seed.decks;
        first.flashcards = seed.flashcards;
        await first.save();
        final id = await first.createReviewSession(
          draft(),
          at: DateTime(2026, 11, 2, 10),
        );
        final second = MochiStore(cloudService: cloud);
        await second.init();
        expect(second.learning.reviewSessions.single['status'], 'active');
        if (deleted) {
          first.flashcards.clear();
          await first.save();
        } else {
          await first.editKnowledgeCard(
            'c',
            'Updated question',
            'Updated answer',
          );
        }
        await second.refreshCloudAuth();
        expect(second.learning.reviewSessions.single['status'], 'invalidated');
        await expectLater(second.gradeReviewCard(id, 'c', 3), throwsStateError);
        expect(second.tasks.where((t) => t.id == id), isEmpty);
        seed.dispose();
        first.dispose();
        second.dispose();
      },
    );
  }

  test('second device resumes grades and completion from first', () async {
    final seed = makeStore();
    final cloud = FakeCloud();
    final first = MochiStore(cloudService: cloud);
    await first.init();
    first.dailyRoutine = seed.dailyRoutine;
    first.decks = seed.decks;
    first.flashcards = seed.flashcards;
    await first.save();
    final id = await first.createReviewSession(
      draft(),
      at: DateTime(2026, 11, 2, 10),
    );
    final second = MochiStore(cloudService: cloud);
    await second.init();
    await first.gradeReviewCard(id, 'c', 2);
    await second.refreshCloudAuth();
    expect(second.learning.reviewSessions.single['grades']['c']['grade'], 2);
    await second.skipReviewQuiz(id);
    await first.refreshCloudAuth();
    expect(first.learning.reviewSessions.single['status'], 'completed');
    seed.dispose();
    first.dispose();
    second.dispose();
  });

  for (final width in [320.0, 768.0, 1366.0]) {
    testWidgets('library search, due filter and reading at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = makeStore();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: const FlashcardsScreen(),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Công sai');
      await tester.pumpAndSettle();
      expect(find.text('1 thẻ phù hợp'), findsOneWidget);
      await tester.tap(find.text('Đến hạn ôn'));
      await tester.pumpAndSettle();
      expect(find.text('1 thẻ phù hợp'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(
        find.text('Không tìm thấy thẻ. Hãy đổi từ khóa hoặc bộ lọc.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  for (final guest in [true, false]) {
    testWidgets('review works with ${guest ? 'guest' : 'failed gateway'}', (
      tester,
    ) async {
      final seed = makeStore();
      final cloud = FakeCloud();
      if (guest) cloud.currentUserId = null;
      final store =
          MochiStore(
              cloudService: cloud,
              aiService: AIService(
                client: MockClient(
                  (_) async => http.Response('Unavailable', 503),
                ),
              ),
            )
            ..dailyRoutine = seed.dailyRoutine
            ..decks = seed.decks
            ..flashcards = seed.flashcards;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(home: ReviewScreen(active: true)),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.text('Ôn offline · Dùng nội dung đã lưu, không có quiz AI.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Xem giải thích'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem giải thích'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nhớ'));
      await tester.ensureVisible(find.text('Nhớ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhớ'));
      await tester.pumpAndSettle();
      expect(find.text('Đã hoàn thành lượt ôn'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      seed.dispose();
    });
  }
}
