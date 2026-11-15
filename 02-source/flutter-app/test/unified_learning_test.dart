import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/core/learning/learning_models.dart';
import 'package:mochi_app/core/learning/unified_study_planner.dart';
import 'package:mochi_app/core/learning/curriculum_catalog.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(
    2026,
    11,
    2,
    8,
  ); // Monday; explicit test clock, no claim about learner pace.
  final engine = UnifiedStudyPlanner();
  DailyRoutine routine({
    int budget = 120,
    String start = '19:00',
    String end = '21:00',
  }) => DailyRoutine(
    eveningFreeStart: start,
    eveningFreeEnd: end,
    preferredDailyMinutes: budget,
  );
  TaskModel task(
    String id, {
    String kind = 'practice',
    int minutes = 45,
    DateTime? due,
    String subject = 'Toán',
    List<String> topics = const [],
    List<String> goalIds = const [],
  }) => TaskModel(
    id: id,
    title: id,
    subject: subject,
    durationMinutes: minutes,
    kind: kind,
    dueAt: due,
    topicIds: topics,
    goalIds: goalIds,
    createdAt: now,
  );
  test('twelve subjects share one budget including breaks, mandatory work gets capacity first', () {
    final tasks = [
      for (var i = 0; i < 12; i++) task('goal$i', subject: 'Môn$i'),
      task(
        'homework',
        kind: 'homework',
        minutes: 60,
        due: DateTime(2026, 11, 3, 8),
      ),
    ];
    final plan = engine.build(
      now: now,
      tasks: tasks,
      goals: [],
      routine: routine(),
      learning: LearningState(),
      days: 1,
    );
    expect(plan.blocks.first.taskId, 'homework');
    final minutes = plan.blocks.fold<int>(0, (s, b) => s + b.minutes);
    expect(minutes + (plan.blocks.length - 1) * 5, lessThanOrEqualTo(120));
    expect(plan.deferred, isNotEmpty);
    for (var i = 1; i < plan.blocks.length; i++) {
      final previous = plan.blocks[i - 1], current = plan.blocks[i];
      int clock(String x) {
        final p = x.split(':').map(int.parse).toList();
        return p[0] * 60 + p[1];
      }

      expect(
        clock(current.startTime),
        greaterThanOrEqualTo(clock(previous.startTime) + previous.minutes + 5),
      );
    }
  });
  test('school lessons exclude actual time; no assumption every unlisted school hour is free', () {
    final learning = LearningState(
      timetable: [
        SchoolLesson(
          id: 'school',
          subject: 'Anh',
          weekday: 1,
          startTime: '19:00',
          endTime: '20:00',
        ),
      ],
    );
    final plan = engine.build(
      now: now,
      tasks: [task('study')],
      goals: [],
      routine: routine(),
      learning: learning,
      days: 1,
    );
    expect(plan.blocks.single.startTime, '20:00');
  });
  test('long homework splits across days without duplicating parent or moving due date', () {
    final due = DateTime(2026, 11, 3, 20);
    final plan = engine.build(
      now: now,
      tasks: [task('hw', kind: 'homework', minutes: 120, due: due)],
      goals: [],
      routine: routine(budget: 60),
      learning: LearningState(),
      days: 7,
    );
    expect(plan.blocks.map((b) => b.taskId).toSet(), {'hw'});
    expect(plan.deferred.single.remainingMinutes, greaterThan(0));
    for (final b in plan.blocks) {
      expect(
        DateTime.parse('${b.date}T${b.startTime}')
            .add(Duration(minutes: b.minutes))
            .isAfter(due),
        false,
      );
    }
  });
  test('a shared activity is scheduled once for multiple goals', () {
    final plan = engine.build(
      now: now,
      tasks: [
        task('shared', minutes: 25, goalIds: ['g1', 'g2']),
      ],
      goals: [],
      routine: routine(),
      learning: LearningState(),
      days: 1,
    );
    expect(plan.blocks.length, 1);
    expect(plan.blocks.single.minutes, 25);
  });
  test('self-reported confident topic skips new whole-lesson teaching but not homework', () {
    final l = LearningState(
      progress: [
        TopicProgress(
          id: 'p',
          courseId: 'c',
          topicId: 'topic',
          readiness: TopicReadiness.confident,
          updatedAt: now,
        ),
      ],
    );
    final plan = engine.build(
      now: now,
      tasks: [
        task('lesson', kind: 'learn', topics: ['topic']),
        task('assignment', kind: 'homework', topics: ['topic']),
      ],
      goals: [],
      routine: routine(),
      learning: l,
      days: 1,
    );
    expect(plan.blocks.any((b) => b.taskId == 'lesson'), false);
    expect(plan.blocks.any((b) => b.taskId == 'assignment'), true);
    expect(l.readinessFor('missing'), TopicReadiness.unknown);
  });
  test('progress and study events round-trip and do not promote mastery from timer events', () {
    final l = LearningState(
      gradeLevel: 11,
      studyEvents: [
        {'id': 's', 'taskId': 't', 'blockId': 'b', 'minutes': 20},
      ],
      progress: [],
    );
    final restored = LearningState.fromJson(l.toJson());
    expect(restored.completedMinutesForTask('t'), 20);
    expect(restored.readinessFor('t'), TopicReadiness.unknown);
  });
  test('parity needs anchor and respects effective date, not guessed school week numbering', () {
    const l = SchoolLesson(
      id: 'a',
      subject: 'Toán',
      weekday: 1,
      startTime: '08:00',
      endTime: '09:00',
      weekPattern: 'even',
      parityAnchor: '2026-11-02',
      effectiveFrom: '2026-11-02',
    );
    expect(l.occursOn(DateTime(2026, 11, 2)), true);
    expect(l.occursOn(DateTime(2026, 11, 9)), false);
    expect(l.occursOn(DateTime(2026, 11, 16)), true);
    expect(l.occursOn(DateTime(2026, 10, 26)), false);
  });
  test('catalog gives source-backed math headings only for the actually reviewed grade', () {
    expect(CurriculumCatalog.courseFor('Toán', 11).topics.length, 25);
    expect(CurriculumCatalog.courseFor('Toán', 10).topics, isEmpty);
    expect(
      CurriculumCatalog.courseFor(
        'Toán',
        11,
      ).topics.every((t) => t.sourceRef.contains('pdf-page=')),
      true,
    );
  });
  test('stale preview cannot apply; repeat checkbox cannot farm reward; split focus does not complete parent', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MochiStore();
    store.dailyRoutine = routine();
    store.tasks = [task('parent', minutes: 90)];
    final preview = store.previewUnifiedPlan(now: now);
    store.addTask(title: 'New homework');
    await expectLater(store.acceptUnifiedPlan(preview), throwsStateError);
    store.toggleTask('parent', true);
    final stars = store.stars;
    store.toggleTask('parent', true);
    store.toggleTask('parent', false);
    store.toggleTask('parent', true);
    expect(store.stars, stars);
    store.toggleTask('parent', false);
    store.completeStudySession(
      taskId: 'parent',
      taskTitle: 'parent',
      mode: 'pomodoro',
      activeMinutes: 20,
      operationKey: 'op',
      learningBlockId: 'b',
      completeTask: false,
    );
    final earned = store.stars;
    store.completeStudySession(
      taskId: 'parent',
      taskTitle: 'parent',
      mode: 'pomodoro',
      activeMinutes: 20,
      operationKey: 'op',
      learningBlockId: 'b',
      completeTask: false,
    );
    expect(store.tasks.firstWhere((t) => t.id == 'parent').isDone, false);
    expect(store.learning.completedMinutesForTask('parent'), 20);
    expect(store.stars, earned);
  });
}
