import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mochi_app/core/services/ai_service.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/services/schedule_change_policy.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/core/learning/learning_models.dart';

import 'account_sync_test.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  TaskModel task() => TaskModel(
    id: 't',
    title: 'Bài Toán chương 1',
    durationMinutes: 25,
    scheduledDate: '2026-11-02',
    scheduledTime: '19:30',
  );
  Map<String, dynamic> action(TaskModel t) => {
    'action': 'reschedule_task',
    'ownerId': 'account-one',
    'taskId': t.id,
    'expectedTask': jsonEncode(t.toJson()),
    'date': '2026-11-02',
    'newTime': '20:30',
    'status': 'proposed',
  };
  test('validates future available slot, rejects stale task, lock, invalid date and conflict', () {
    final t = task();
    final a = action(t);
    final tasks = [t];
    final learning = LearningState();
    const routine = DailyRoutine();
    TaskModel validate() => ScheduleChangePolicy.validate(
      action: a,
      tasks: tasks,
      routine: routine,
      learning: learning,
      now: DateTime(2026, 11, 2, 10),
    );
    expect(validate().id, 't');
    t.title = 'edited';
    expect(validate, throwsStateError);
    t.title = 'Bài Toán chương 1';
    a['date'] = '2026-02-31';
    expect(validate, throwsStateError);
    a['date'] = '2026-11-02';
    tasks.add(
      TaskModel(
        id: 'busy',
        title: 'Văn',
        scheduledDate: '2026-11-02',
        scheduledTime: '20:20',
        durationMinutes: 30,
      ),
    );
    expect(validate, throwsStateError);
    tasks.removeLast();
    tasks[0] = t.copyWith(scheduleLocked: true);
    a['expectedTask'] = jsonEncode(tasks[0].toJson());
    expect(validate, throwsStateError);
  });
  test('does not move deadlines or consume a second study budget', () {
    final t = task().copyWith(dueAt: DateTime(2026, 11, 2, 20, 40));
    final a = action(t);
    expect(
      () => ScheduleChangePolicy.validate(
        action: a,
        tasks: [t],
        routine: const DailyRoutine(),
        learning: LearningState(),
        now: DateTime(2026, 11, 2, 10),
      ),
      throwsStateError,
    );
    final t2 = task();
    expect(
      () => ScheduleChangePolicy.validate(
        action: action(t2),
        tasks: [t2],
        routine: const DailyRoutine(preferredDailyMinutes: 30),
        learning: LearningState(),
        now: DateTime(2026, 11, 2, 10),
        spentMinutes: 15,
      ),
      throwsStateError,
    );
  });
  test('confirm updates exact task and persistent proposal atomically, repeat cannot reapply', () async {
    final store = MochiStore(cloudService: FakeCloud());
    final t = task();
    store.tasks = [t];
    await store.recordTutorMessage(
      ChatMessageModel(
        id: 'proposal',
        role: 'assistant',
        content: 'Đề xuất',
        scheduleActionData: action(t),
      ),
    );
    await store.confirmTutorScheduleChange(
      'proposal',
      at: DateTime(2026, 11, 2, 10),
    );
    expect(store.tasks.single.scheduledTime, '20:30');
    expect(store.tutorMessages.single.scheduleActionData!['status'], 'applied');
    await store.confirmTutorScheduleChange(
      'proposal',
      at: DateTime(2026, 11, 2, 10),
    );
    expect(store.tasks.length, 1);
    store.dispose();
  });
  test('wrong owner and deleted task never report success', () async {
    final store = MochiStore(cloudService: FakeCloud());
    final t = task();
    final a = action(t)..['ownerId'] = 'someone-else';
    store.tasks = [t];
    await store.recordTutorMessage(
      ChatMessageModel(
        id: 'p',
        role: 'assistant',
        content: 'x',
        scheduleActionData: a,
      ),
    );
    await expectLater(
      store.confirmTutorScheduleChange('p', at: DateTime(2026, 11, 2, 10)),
      throwsStateError,
    );
    expect(store.tasks.single.scheduledTime, '19:30');
    store.dispose();
  });
  test('JSON response-format prompt satisfies live provider contract and binds real task snapshot', () async {
    final t = task();
    final ai = AIService(
      client: MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['messages'].toString().toLowerCase(), contains('json'));
        expect(body['messages'][1]['content'], contains(t.id));
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'stop',
                  'message': {
                    'content': jsonEncode({
                      'action': 'reschedule_task',
                      'taskId': t.id,
                      'date': '2026-11-02',
                      'newTime': '20:30',
                    }),
                  },
                },
              ],
            }),
          ),
          200,
        );
      }),
    );
    final proposal = await ai.proposeScheduleChange(
      message: 'Dời việc',
      tasks: [t],
      now: DateTime(2026, 11, 2, 10),
    );
    expect(proposal['expectedTask'], jsonEncode(t.toJson()));
    expect(proposal['taskTitle'], t.title);
  });
}
