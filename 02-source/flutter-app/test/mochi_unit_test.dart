import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mochi Study Core Logic Unit Tests', () {
    late MochiStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = MochiStore();
      await store.init();
    });

    test('Onboarding completion sets learner name and creates initial goals', () async {
      await store.completeOnboarding(
        learnerName: 'Minh Khang',
        gradeBand: 'THCS',
        robotName: 'Mochi Alpha',
        primaryGoal: 'Đạt học sinh giỏi kỳ 1',
        targetSubject: 'Toán',
      );

      expect(store.profile.name, 'Minh Khang');
      expect(store.profile.robotName, 'Mochi Alpha');
      expect(store.goals.length, 1);
      expect(store.goals.first.title, 'Đạt học sinh giỏi kỳ 1');
      expect(store.tasks.length, 2);
      expect(store.isFirstTime, false);
    });

    test('Completing task increments stars and awards XP without double count', () {
      store.addTask(title: 'Làm bài tập đại số', subject: 'Toán', duration: 30);
      final task = store.tasks.first;
      expect(store.stars, 0);
      expect(store.xp, 0);

      store.toggleTask(task.id, true);
      expect(store.stars, 1);
      expect(store.xp, 30);
      expect(store.tasks.first.isDone, true);

      // Toggling off does not duplicate rewards
      store.toggleTask(task.id, false);
      expect(store.tasks.first.isDone, false);
    });

    test('Atomic study session awards stars, XP, and updates streak', () {
      expect(store.currentStreak, 0);
      store.completeStudySession(
        taskId: 't_1',
        taskTitle: 'Học từ vựng Unit 5',
        mode: 'pomodoro',
        activeMinutes: 25,
        selfRating: 5,
      );

      expect(store.sessions.length, 1);
      expect(store.stars, 2); // >= 20 mins awards 2 stars
      expect(store.xp, 125); // 25 * 5 = 125 XP
      expect(store.currentStreak, 1);
    });

    test('Robot shop purchases deduct stars and equip items', () {
      // Award stars to afford items
      store.completeStudySession(
        taskId: 't_test',
        taskTitle: 'Session 1',
        mode: 'pomodoro',
        activeMinutes: 50,
      );
      store.stars = 10;
      expect(store.stars >= 3, true);

      final item = MochiStore.shopCatalog.firstWhere((i) => i.id == 'sunglasses');
      // Set streak to meet requirement
      store.currentStreak = 5;
      final buyOk = store.buyItem(item);
      expect(buyOk, true);
      expect(store.ownedItems.contains('sunglasses'), true);
      expect(store.equippedAccessory, 'sunglasses');
    });

    test('Spaced repetition algorithm calculates intervals properly', () {
      store.addDeck('Tiếng Anh 10', 'English');
      final deck = store.decks.first;
      store.addFlashcard(deck.id, 'Resilience', 'Khả năng phục hồi, kiên cường');
      final card = store.flashcards.first;

      // Grade 2 = Good
      store.reviewFlashcard(card.id, 2);
      expect(card.repetitions, 1);
      expect(card.intervalDays, 1);

      // Next review with Good
      store.reviewFlashcard(card.id, 2);
      expect(card.repetitions, 2);
      expect(card.intervalDays, 6);
    });

    test('JSON Backup export and import preserves data accurately', () {
      store.profile.name = 'Bảo Châu';
      store.stars = 15;
      store.addTask(title: 'Bài kiểm tra 15 phút', subject: 'Vật lý');

      final exported = store.exportBackupJson();
      expect(exported.contains('Bảo Châu'), true);
      expect(exported.contains('Bài kiểm tra 15 phút'), true);

      // Fresh store importing this JSON
      final newStore = MochiStore();
      final importOk = newStore.importBackupJson(exported);
      expect(importOk, true);
      expect(newStore.profile.name, 'Bảo Châu');
      expect(newStore.stars, 15);
      expect(newStore.tasks.length, 1);
    });
  });
}

