import '../models/mochi_models.dart';
import '../models/tutor_quiz.dart';
import '../services/study_schedule.dart';
import 'learning_models.dart';

/// Recall estimates constrain AI suggestions, not a declaration of mastery.
class ReviewPolicy {
  static List<FlashcardItem> dueCards({
    required DateTime now,
    required List<FlashcardItem> cards,
    required List<FlashcardDeck> decks,
    required LearningState learning,
  }) {
    final eligible = cards.where((c) {
      final deck = decks.where((d) => d.id == c.deckId).firstOrNull;
      if (deck == null ||
          c.nextReviewAt.isAfter(now) ||
          c.front.trim().isEmpty ||
          c.back.trim().isEmpty)
        return false;
      // Discard known legacy canned answers; never call those real study content.
      if (c.back.contains('Là phần kiến thức nền tảng quan trọng nhất'))
        return false;
      if (deck.topicIds.isNotEmpty &&
          deck.topicIds.every(
            (id) => learning.readinessFor(id) == TopicReadiness.notStudied,
          ))
        return false;
      return true;
    }).toList();
    int weakness(FlashcardItem c) {
      final deck = decks.firstWhere((d) => d.id == c.deckId);
      return deck.topicIds.any(
            (id) => learning.readinessFor(id) == TopicReadiness.needsReview,
          )
          ? 0
          : 1;
    }

    eligible.sort((a, b) {
      final w = weakness(a).compareTo(weakness(b));
      if (w != 0) return w;
      final r = a.repetitions.compareTo(b.repetitions);
      return r != 0 ? r : a.nextReviewAt.compareTo(b.nextReviewAt);
    });
    return eligible.take(12).toList();
  }

  /// Remaining real capacity today, including school and already planned work.
  static int availableMinutes({
    required DateTime now,
    required DailyRoutine routine,
    required LearningState learning,
    required List<TaskModel> tasks,
    required List<StudySessionRecord> sessions,
  }) {
    final date = learningDateKey(now), occupied = <List<int>>[];
    for (final range in routine.busyOn(now)) {
      occupied.add(scheduleRange(range));
    }
    for (final l in learning.timetable.where((l) => l.occursOn(now))) {
      occupied.add([scheduleMinute(l.startTime), scheduleMinute(l.endTime)]);
    }
    for (final t in tasks.where(
      (t) => !t.isDone && t.scheduledDate == date && t.scheduledTime != null,
    )) {
      final start = scheduleMinute(t.scheduledTime!);
      occupied.add([start, start + t.durationMinutes]);
    }
    final blocks = learning.activePlan?.blocks ?? [];
    for (final b in blocks.where((b) => b.date == date)) {
      final start = scheduleMinute(b.startTime);
      occupied.add([start, start + b.minutes]);
    }
    final minutes = <int>{};
    for (final range in routine.freeOn(now)) {
      final bounds = scheduleRange(range);
      for (var m = bounds[0]; m < bounds[1]; m++) {
        if (m >= now.hour * 60 + now.minute &&
            !occupied.any((b) => m >= b[0] && m < b[1]))
          minutes.add(m);
      }
    }
    final used = sessions
        .where((s) => learningDateKey(s.endedAt) == date)
        .fold<int>(0, (sum, s) => sum + s.activeSeconds ~/ 60);
    final committed = tasks
        .where((t) => !t.isDone && t.scheduledDate == date)
        .fold<int>(0, (sum, t) => sum + t.durationMinutes);
    final scheduledTaskIds = tasks
        .where((t) => t.scheduledDate == date)
        .map((t) => t.id)
        .toSet();
    final planned = blocks
        .where((b) => b.date == date && !scheduledTaskIds.contains(b.taskId))
        .fold<int>(
          0,
          (sum, b) =>
              sum +
              (b.minutes - learning.completedMinutesForBlock(b.id)).clamp(
                0,
                b.minutes,
              ),
        );
    // Do not allocate a second study budget to revision.
    final remaining =
        (routine.preferredDailyMinutes - used - committed - planned).clamp(
          0,
          1440,
        );
    return minutes.length < remaining ? minutes.length : remaining;
  }

  /// Recall from saved content only; no generated questions or answer keys.
  static Map<String, dynamic> offlineDraft(
    List<FlashcardItem> due,
    int budget,
  ) {
    if (due.isEmpty || budget < 2) {
      throw StateError('Chưa có thẻ đến hạn hoặc thời gian ôn phù hợp.');
    }
    final selected = due.take((budget ~/ 2).clamp(1, 6)).toList();
    return {
      'mode': 'offline',
      'cardIds': selected.map((c) => c.id).toList(),
      'durationMinutes': selected.length * 2,
      'reason': 'Ôn thẻ đã lưu, ưu tiên kiến thức cần ôn và thẻ đến hạn. Không cần kết nối AI.',
      'quiz': {
        'topic': 'Thẻ đã lưu',
        'questions': <dynamic>[],
        'answers': <String, dynamic>{},
      },
    };
  }

  static Map<String, dynamic> validateDraft(
    dynamic draft,
    List<FlashcardItem> candidates,
    int budget,
  ) {
    if (draft is! Map ||
        draft['cardIds'] is! List ||
        draft['durationMinutes'] is! int ||
        draft['reason'] is! String ||
        draft['reason'].toString().trim().isEmpty) {
      throw const FormatException('Lượt ôn chưa hợp lệ.');
    }
    final ids = List<String>.from(draft['cardIds']);
    final allowed = candidates.map((c) => c.id).toSet();
    if (ids.isEmpty ||
        ids.length > 6 ||
        ids.toSet().length != ids.length ||
        !ids.every(allowed.contains) ||
        draft['durationMinutes'] < 1 ||
        draft['durationMinutes'] > budget) {
      throw const FormatException(
        'Lượt ôn vượt lịch hoặc dùng thẻ ngoài phạm vi.',
      );
    }
    final quiz = validateTutorQuiz(draft['quiz']);
    for (final q in quiz['questions'] as List) {
      if (!ids.contains(q['sourceCardId']))
        throw const FormatException(
          'Quiz chưa liên kết kiến thức của lượt ôn.',
        );
    }
    return {...Map<String, dynamic>.from(draft), 'mode': 'ai', 'quiz': quiz};
  }
}
