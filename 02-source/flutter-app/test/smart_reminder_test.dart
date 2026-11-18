import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/core/services/reminder_copy_writer.dart';
import 'package:mochi_app/core/services/smart_reminder_policy.dart';
import 'package:mochi_app/core/services/smart_reminder_service.dart';
import 'package:mochi_app/features/settings/smart_reminder_settings.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 2, 9);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const policy = SmartReminderPolicy();
  TaskModel task(String id, String date, String time, {bool done = false}) =>
      TaskModel(
        id: id,
        title: 'Đại số $id',
        scheduledDate: date,
        scheduledTime: time,
        isDone: done,
      );
  List<PlannedReminder> plan(
    List<TaskModel> tasks, {
    DateTime? at,
    List<DateTime> ledger = const [],
  }) => policy.plan(
    now: at ?? now,
    tasks: tasks,
    lastAppOpen: at ?? now,
    lastStudyActivity: at ?? now,
    learnerName: 'Lộc',
    pastReservations: ledger,
  );

  test('task date/time are strict and invalid dates do not roll into another month', () {
    expect(
      SmartReminderPolicy.taskDueTime(task('x', '2026-02-30', '10:00')),
      isNull,
    );
    expect(
      SmartReminderPolicy.taskDueTime(task('x', '2026-11-02', '25:00')),
      isNull,
    );
    expect(
      SmartReminderPolicy.taskDueTime(task('x', '2026-11-02', '10:30')),
      DateTime(2026, 11, 2, 10, 30),
    );
  });

  test(
    'due and overdue follow-up use recorded task times and local task wording',
    () {
      final result = plan([task('math', '2026-11-02', '10:00')]);
      final due = result.firstWhere((r) => r.kind == ReminderKind.due);
      final overdue = result.firstWhere((r) => r.kind == ReminderKind.overdue);
      expect(due.when, DateTime(2026, 11, 2, 10));
      expect(overdue.when, DateTime(2026, 11, 2, 13));
      expect(due.body, contains('Đại số math'));
      expect(due.body, contains('Lộc'));
      expect(due.source, 'rules');
    },
  );

  test('completed and deleted tasks have no pending task reminders', () {
    expect(
      plan([task('done', '2026-11-02', '10:00', done: true)])
          .where((r) => r.taskId != null),
      isEmpty,
    );
    expect(plan([]).where((r) => r.taskId != null), isEmpty);
  });

  test('unscheduled tasks do not invent a due time', () {
    final result = plan([TaskModel(id: 'x', title: 'Chưa có lịch')]);
    expect(result.where((r) => r.taskId != null), isEmpty);
  });

  test(
    'quiet hours defer to the next allowed window, across month boundaries',
    () {
      final result = plan([
        task('night', '2026-11-30', '23:00'),
      ], at: DateTime(2026, 11, 30, 20));
      expect(
        result.where(
          (r) => r.kind != ReminderKind.due && policy.isQuiet(r.when),
        ),
        isEmpty,
      );
      expect(
        result.firstWhere((r) => r.kind == ReminderKind.due).when,
        DateTime(2026, 11, 30, 23),
      );
      final overdue = result.firstWhere(
        (r) => r.taskId == 'night' && r.kind == ReminderKind.overdue,
      );
      expect(overdue.when, DateTime(2026, 12, 1, 8));
    },
  );

  test('automatic reminders are capped at two a day and spaced at least three hours', () {
    final result = plan([
      for (var h = 10; h < 22; h++) task('t$h', '2026-11-02', '$h:00'),
    ]);
    final today = result
        .where((r) => r.when.day == 2 && r.kind != ReminderKind.due)
        .toList();
    expect(result.where((r) => r.kind == ReminderKind.due).length, 12);
    expect(today.length, lessThanOrEqualTo(2));
    if (today.length == 2) {
      expect(
        today[1].when.difference(today[0].when),
        greaterThanOrEqualTo(const Duration(hours: 3)),
      );
    }
  });

  test(
    'opening/replanning does not reset the already-reserved daily quota',
    () {
      final result = plan(
        [task('x', '2026-11-02', '18:00')],
        ledger: [DateTime(2026, 11, 2, 8), DateTime(2026, 11, 2, 12)],
      );
      expect(
        result.where((r) => r.when.day == 2 && r.kind != ReminderKind.due),
        isEmpty,
      );
      expect(result.where((r) => r.kind == ReminderKind.due), hasLength(1));
    },
  );

  test('inactivity reminders are prepared without a background AI process', () {
    final result = plan([]);
    expect(
      result.any(
        (r) =>
            r.kind == ReminderKind.inactiveStudy &&
            r.when == now.add(const Duration(days: 2)),
      ),
      isTrue,
    );
    expect(
      result.any(
        (r) =>
            r.kind == ReminderKind.inactiveApp &&
            r.when == now.add(const Duration(days: 3)),
      ),
      isTrue,
    );
    expect(
      result.every((r) => !r.when.isAfter(now.add(const Duration(days: 7)))),
      isTrue,
    );
  });

  test('tasks more than a week away keep their appointment reminder', () {
    final result = plan([task('far', '2026-11-12', '09:00')]);
    final due = result.where(
      (r) => r.taskId == 'far' && r.kind == ReminderKind.due,
    );
    expect(due, hasLength(1));
    expect(due.single.when, DateTime(2026, 11, 12, 9));
    // Optional nudges still stay inside the 7-day window.
    expect(
      result.where(
        (r) =>
            r.kind != ReminderKind.due &&
            r.when.isAfter(now.add(const Duration(days: 7))),
      ),
      isEmpty,
    );
  });

  test('resuming study resets study inactivity, returning to app resets app inactivity', () {
    final result = policy.plan(
      now: now,
      tasks: [],
      learnerName: 'Lộc',
      lastStudyActivity: now,
      lastAppOpen: now,
    );
    expect(
      result.every((r) => !r.when.isBefore(now.add(const Duration(days: 2)))),
      isTrue,
    );
  });

  test('old unfinished tasks get a delayed nudge, never a notification instantly on launch', () {
    final result = plan([task('old', '2026-10-20', '10:00')]);
    final followUp = result.firstWhere((r) => r.taskId == 'old');
    expect(followUp.kind, ReminderKind.overdue);
    expect(followUp.when, now.add(const Duration(hours: 2)));
  });

  test('IDs are stable, scoped away from timers and preserved when wording changes', () {
    final a = plan([task('x', '2026-11-02', '10:00')]).first;
    final b = plan([task('x', '2026-11-02', '10:00')]).first;
    expect(a.id, b.id);
    expect(a.id, greaterThanOrEqualTo(1500000000));
    expect(a.id, lessThan(2147483647));
    expect(DateTime.parse(a.toJson()['when'] as String), a.when.toUtc());
  });

  final goodCopy = {
    'due': '{name} ơi, mình bắt đầu {task} nhé?',
    'overdue': '{task} chưa được đánh dấu xong. Mình tiếp tục nhé?',
    'inactiveStudy': '{name} ơi, dành một phiên học ngắn cùng Mochii nhé?',
    'inactiveApp': '{name} ơi, ghé xem lại kế hoạch học nhé!',
  };

  test('AI copy is validated and interpolated locally', () {
    final copy = ReminderCopyWriter.parse(jsonEncode(goodCopy));
    expect(copy.source, 'ai');
    expect(
      copy.render(ReminderKind.due, name: 'Lộc', task: 'Toán'),
      'Lộc ơi, mình bắt đầu Toán nhé?',
    );
  });

  test('AI malformed, missing-placeholder, overlong, URL and emoji text is rejected', () {
    for (final bad in [
      {...goodCopy}..remove('due'),
      {...goodCopy, 'due': 'Làm ngay!'},
      {...goodCopy, 'due': '{task} https://example.com'},
      {...goodCopy, 'due': '{task} {unknown}'},
      {...goodCopy, 'due': '{task} ${'a' * 200}'},
      {...goodCopy, 'due': '{task} \u{1F525}'},
    ]) {
      expect(
        () => ReminderCopyWriter.parse(jsonEncode(bad)),
        throwsFormatException,
      );
    }
  });

  test('AI requests generic templates, not learner names, tasks or activity history', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['messages'].toString(), contains('{task}'));
      expect(body['messages'].toString(), isNot(contains('Thành Lộc')));
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'content': jsonEncode(goodCopy)},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final copy = await ReminderCopyWriter(client: client).generate(AIService());
    expect(copy.source, 'ai');
  });

  test(
    'AI service failure remains a failure so rules are not mislabelled as AI',
    () async {
      final client = MockClient((_) async => http.Response('unavailable', 503));
      await expectLater(
        ReminderCopyWriter(client: client).generate(AIService()),
        throwsStateError,
      );
    },
  );

  test(
    'store preserves scheduled times and gives rapid task creation unique IDs',
    () async {
      final store = MochiStore();
      store.addTask(
        title: 'A',
        scheduledDate: '2026-11-02',
        scheduledTime: '10:00',
      );
      store.addTask(
        title: 'B',
        scheduledDate: '2026-11-02',
        scheduledTime: '11:00',
      );
      expect(store.tasks.map((t) => t.id).toSet(), hasLength(2));
      expect(store.tasks.first.scheduledDate, '2026-11-02');
      expect(store.tasks.first.scheduledTime, '10:00');
      await store.save();
    },
  );

  test('coordinator schedules native alarms and cancels done tasks without cancelling timers', () async {
    SharedPreferences.setMockInitialValues({
      'mochii_smart_v1_ai_enabled': false,
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'initialize' ||
          call.method == 'areNotificationsEnabled') {
        return true;
      }
      if (call.method == 'canScheduleExactNotifications') return false;
      if (call.method == 'pendingNotificationRequests') {
        return <Map<String, dynamic>>[];
      }
      return null;
    });
    final future = DateTime.now().add(const Duration(hours: 4));
    final store = MochiStore()
      ..isLoaded = true
      ..isFirstTime = false;
    store.profile.name = 'Lộc';
    store.tasks = [
      task(
        'pending',
        '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}',
        '${future.hour.toString().padLeft(2, '0')}:00',
      ),
    ];
    final service = SmartReminderService();
    await service.start(store);
    expect(calls.any((c) => c.method == 'zonedSchedule'), isTrue);
    final taskIds = service.scheduled
        .where((r) => r.taskId == 'pending')
        .map((r) => r.id)
        .toSet();
    expect(taskIds, isNotEmpty);
    store.tasks.first.isDone = true;
    calls.clear();
    await service.refresh();
    expect(service.scheduled.where((r) => r.taskId == 'pending'), isEmpty);
    final cancelled = calls
        .where((c) => c.method == 'cancel')
        .map((c) => c.arguments['id'])
        .toSet();
    expect(cancelled.containsAll(taskIds), isTrue);
    expect(cancelled, isNot(contains(9999)));
    await service.setEnabled(false);
    expect(service.scheduled, isEmpty);
    await service.stop();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('concurrent and repeated start calls are safe', () async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'initialize' ||
          call.method == 'areNotificationsEnabled') {
        return true;
      }
      if (call.method == 'canScheduleExactNotifications') return false;
      if (call.method == 'pendingNotificationRequests') {
        return <Map<String, dynamic>>[];
      }
      return null;
    });
    final store = MochiStore()
      ..isLoaded = true
      ..isFirstTime = false;
    store.profile.name = 'Lộc';

    final service = SmartReminderService();
    // The second caller must wait for the first initialization instead of
    // seeing a half-ready service.
    await Future.wait([service.start(store), service.start(store)]);
    expect(service.enabled, isTrue);
    expect(service.scheduled, isNotEmpty);

    await service.start(store);
    expect(service.scheduled, isNotEmpty);

    await service.stop();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('one failing alarm keeps every later reminder scheduled', () async {
    SharedPreferences.setMockInitialValues({
      'mochii_smart_v1_ai_enabled': false,
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    var scheduleCalls = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'initialize' ||
          call.method == 'areNotificationsEnabled') {
        return true;
      }
      if (call.method == 'canScheduleExactNotifications') return false;
      if (call.method == 'pendingNotificationRequests') {
        return <Map<String, dynamic>>[];
      }
      if (call.method == 'zonedSchedule') {
        scheduleCalls++;
        // Simulate one alarm rejected by the OS (for example a stale
        // SecurityException after the learner revoked exact alarms).
        if (scheduleCalls == 2) {
          throw PlatformException(code: 'schedule_failed');
        }
        return null;
      }
      return null;
    });
    final future = DateTime.now().add(const Duration(hours: 4));
    final date =
        '${future.year}-${future.month.toString().padLeft(2, '0')}-'
        '${future.day.toString().padLeft(2, '0')}';
    final time =
        '${future.hour.toString().padLeft(2, '0')}:'
        '${future.minute.toString().padLeft(2, '0')}';
    final store = MochiStore()
      ..isLoaded = true
      ..isFirstTime = false;
    store.profile.name = 'Lộc';
    store.tasks = [task('a', date, time), task('b', date, time)];

    final service = SmartReminderService();
    await service.start(store);
    final attempted = calls.where((c) => c.method == 'zonedSchedule').length;
    expect(attempted, greaterThan(2));
    expect(service.scheduled, isNotEmpty);
    expect(service.scheduled.length, attempted - 1);
    expect(service.statusError, isNull);
    expect(service.statusWarning, contains('1/$attempted'));

    await service.stop();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('smart reminder settings fit 320px at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(child: SmartReminderSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nhắc học thông minh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
