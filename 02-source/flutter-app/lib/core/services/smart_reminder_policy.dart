import '../models/mochi_models.dart';

enum ReminderKind { due, overdue, inactiveStudy, inactiveApp }

class ReminderCopy {
  final Map<String, String> templates;
  final String source;
  const ReminderCopy(this.templates, {this.source = 'rules'});

  static const fallback = ReminderCopy({
    'due': '{name} ơi, đến lịch học “{task}” rồi. Bắt đầu một bước nhỏ nhé?',
    'overdue': '“{task}” vẫn chưa được đánh dấu hoàn thành. Mình tiếp tục hoặc đổi lịch cho phù hợp nhé?',
    'inactiveStudy': '{name} ơi, đã một thời gian chưa có hoạt động học được ghi nhận. Dành 10 phút học cùng Mochii nhé?',
    'inactiveApp': '{name} ơi, ghé Mochii xem lại kế hoạch và chọn một việc nhỏ để bắt đầu nhé!',
  });

  String render(ReminderKind kind, {required String name, String task = ''}) {
    final template = templates[kind.name] ?? fallback.templates[kind.name]!;
    return template
        .replaceAll('{name}', name.trim().isEmpty ? 'Bạn' : _clip(name, 24))
        .replaceAll('{task}', _clip(task, 72));
  }

  static String _clip(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit - 1)}…';
}

class PlannedReminder {
  final String key;
  final ReminderKind kind;
  final DateTime when;
  final String body;
  final String? taskId;
  final String source;
  const PlannedReminder({
    required this.key,
    required this.kind,
    required this.when,
    required this.body,
    this.taskId,
    required this.source,
  });

  int get id {
    var hash = 17;
    for (final code in key.codeUnits) {
      hash = (hash * 31 + code) & 0x0fffffff;
    }
    return 1500000000 + hash;
  }

  String get title => switch (kind) {
    ReminderKind.due => 'Đến lịch học cùng Mochii',
    ReminderKind.overdue => 'Xem lại nhiệm vụ học tập',
    ReminderKind.inactiveStudy => 'Một bước nhỏ cho hôm nay',
    ReminderKind.inactiveApp => 'Mochii nhắc bạn quay lại',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'kind': kind.name,
    'when': when.toUtc().toIso8601String(),
    'body': body,
    'source': source,
    'taskId': taskId,
  };
}

/// Pure rules decide timing; AI may only supply pre-generated wording.
class SmartReminderPolicy {
  final int quietStartHour;
  final int quietEndHour;
  final int maxPerDay;
  const SmartReminderPolicy({
    this.quietStartHour = 22,
    this.quietEndHour = 8,
    this.maxPerDay = 2,
  });

  bool isQuiet(DateTime time) => quietStartHour > quietEndHour
      ? time.hour >= quietStartHour || time.hour < quietEndHour
      : time.hour >= quietStartHour && time.hour < quietEndHour;

  DateTime nextAllowed(DateTime time) {
    if (!isQuiet(time)) return time;
    if (quietStartHour > quietEndHour && time.hour >= quietStartHour) {
      return DateTime(time.year, time.month, time.day + 1, quietEndHour);
    }
    return DateTime(time.year, time.month, time.day, quietEndHour);
  }

  List<PlannedReminder> plan({
    required DateTime now,
    required List<TaskModel> tasks,
    required DateTime lastAppOpen,
    required DateTime lastStudyActivity,
    required String learnerName,
    ReminderCopy copy = ReminderCopy.fallback,
    List<DateTime> pastReservations = const [],
  }) {
    final candidates = <PlannedReminder>[];
    final horizon = now.add(const Duration(days: 7));
    void add(ReminderKind kind, DateTime target, {TaskModel? task}) {
      final when = kind == ReminderKind.due ? target : nextAllowed(target);
      if (!when.isAfter(now) || when.isAfter(horizon)) return;
      final key =
          '${kind.name}/${task?.id ?? "activity"}/${when.toIso8601String()}';
      candidates.add(
        PlannedReminder(
          key: key,
          kind: kind,
          when: when,
          body: copy.render(kind, name: learnerName, task: task?.title ?? ''),
          taskId: task?.id,
          source: copy.source,
        ),
      );
    }

    for (final task in tasks.where((t) => !t.isDone)) {
      final due = taskDueTime(task);
      if (due == null) continue;
      if (due.isAfter(now)) {
        add(ReminderKind.due, due, task: task);
      }
      // One follow-up, not an endless repeating alarm for every old task.
      final followUp = due.add(const Duration(hours: 3));
      add(
        ReminderKind.overdue,
        followUp.isAfter(now) ? followUp : now.add(const Duration(hours: 2)),
        task: task,
      );
    }
    for (final days in [2, 4, 6]) {
      final target = lastStudyActivity.add(Duration(days: days));
      // Already inactive at launch: give the learner two hours, never an instant nag.
      if (days == 2 || target.isAfter(now)) {
        add(
          ReminderKind.inactiveStudy,
          target.isAfter(now) ? target : now.add(const Duration(hours: 2)),
        );
      }
    }
    for (final days in [3, 6]) {
      add(ReminderKind.inactiveApp, lastAppOpen.add(Duration(days: days)));
    }
    // Exact task times win over a generic nudge when the daily budget is tight.
    candidates.sort((a, b) {
      final day = DateTime(
        a.when.year,
        a.when.month,
        a.when.day,
      ).compareTo(DateTime(b.when.year, b.when.month, b.when.day));
      if (day != 0) return day;
      final rank = a.kind.index.compareTo(b.kind.index);
      return rank != 0 ? rank : a.when.compareTo(b.when);
    });
    final reserved = [...pastReservations];
    final result = <PlannedReminder>[];
    for (final candidate in candidates) {
      // Explicit task schedules are appointments, not optional engagement nudges.
      // Never suppress a 20:00 task because another task starts at 19:30.
      if (candidate.kind == ReminderKind.due) {
        result.add(candidate);
        continue;
      }
      if (reserved.where((t) => _day(t) == _day(candidate.when)).length >=
          maxPerDay) {
        continue;
      }
      if (reserved.any(
        (t) => t.difference(candidate.when).abs() < const Duration(hours: 3),
      )) {
        continue;
      }
      result.add(candidate);
      reserved.add(candidate.when);
    }
    result.sort((a, b) => a.when.compareTo(b.when));
    return result;
  }

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static DateTime? taskDueTime(TaskModel task) {
    if (task.dueAt != null) return task.dueAt;
    final date = task.scheduledDate;
    final time = task.scheduledTime;
    if (date == null ||
        time == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        !RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      return null;
    }
    final d = date.split('-').map(int.parse).toList();
    final t = time.split(':').map(int.parse).toList();
    if (t[0] > 23 || t[1] > 59) return null;
    final result = DateTime(d[0], d[1], d[2], t[0], t[1]);
    if (result.year != d[0] || result.month != d[1] || result.day != d[2]) {
      return null;
    }
    return result;
  }
}
