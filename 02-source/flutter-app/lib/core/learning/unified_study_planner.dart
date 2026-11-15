import 'dart:convert';

import '../models/mochi_models.dart';
import '../services/study_schedule.dart';
import 'learning_models.dart';

/// One capacity ledger for every subject and goal, not N independent schedules.
/// This is a constraint engine, never presented as generated academic content.
class UnifiedStudyPlanner {
  static String signature({
    required List<TaskModel> tasks,
    required DailyRoutine routine,
    required LearningState learning,
    required List<GoalModel> goals,
  }) => jsonEncode({
    'tasks': tasks.map((x) => x.toJson()).toList(),
    'routine': routine.toJson(),
    'courses': learning.courses.map((x) => x.toJson()).toList(),
    'progress': learning.progress.map((x) => x.toJson()).toList(),
    'timetable': learning.timetable.map((x) => x.toJson()).toList(),
    'goals': goals.map((x) => x.toJson()).toList(),
    'studyEvents': learning.studyEvents,
  });

  UnifiedStudyPlan build({
    required DateTime now,
    required List<TaskModel> tasks,
    required List<GoalModel> goals,
    required DailyRoutine routine,
    required LearningState learning,
    int days = 7,
    int maxBlockMinutes = 45,
    int breakMinutes = 5,
  }) {
    if (days < 1 || days > 31 || maxBlockMinutes < 5 || breakMinutes < 0)
      throw ArgumentError('Khoảng lập lịch không hợp lệ.');
    final budget = routine.preferredDailyMinutes;
    if (budget < 1 || budget > 1440)
      throw ArgumentError('Cần thiết lập tổng số phút học trong ngày.');
    final blocks = <LearningBlock>[], deferred = <LearningDeferral>[];
    final occupied = <String, List<List<int>>>{},
        used = <String, int>{},
        parts = <String, int>{};
    final pending = tasks.where((t) => !t.isDone).toList();
    final taskIds = pending.map((x) => x.id).toSet();
    if (taskIds.length != pending.length)
      throw StateError('Có nhiệm vụ trùng ID, chưa lập lịch.');
    DateTime? deadline(TaskModel task) {
      if (task.dueAt != null) return task.dueAt;
      final linked = goals
          .where(
            (g) =>
                !g.isDone &&
                (g.id == task.goalId || task.goalIds.contains(g.id)),
          )
          .toList();
      if (linked.isEmpty) return null;
      final date = linked
          .map((g) => g.targetDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }

    int rank(TaskModel t) => switch (t.kind) {
      'homework' => 0,
      'preparation' => 1,
      'learn' => 2,
      'practice' => 3,
      'review' => 4,
      'mock' => 3,
      _ => 3,
    };
    pending.sort((a, b) {
      final ad = deadline(a), bd = deadline(b);
      final urgentA =
          ad != null && ad.isBefore(now.add(const Duration(days: 2)));
      final urgentB =
          bd != null && bd.isBefore(now.add(const Duration(days: 2)));
      if (urgentA != urgentB) return urgentA ? -1 : 1;
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      if (ad != null || bd != null) {
        if (ad == null) return 1;
        if (bd == null) return -1;
        final d = ad.compareTo(bd);
        if (d != 0) return d;
      }
      final p = b.priority.compareTo(a.priority);
      return p != 0 ? p : a.createdAt.compareTo(b.createdAt);
    });
    // Validate all imported timetable times, even if a specific lesson is not this week.
    for (final lesson in learning.timetable) {
      if (lesson.weekday < 1 || lesson.weekday > 7)
        throw StateError('Thứ trong thời khóa biểu không hợp lệ.');
      final a = scheduleMinute(lesson.startTime),
          b = scheduleMinute(lesson.endTime);
      if (a >= b)
        throw StateError('Giờ kết thúc tiết học phải sau giờ bắt đầu.');
      if (lesson.weekPattern != 'all' && lesson.parityAnchor == null)
        throw StateError('Cần chọn tuần bắt đầu cho lịch chẵn/lẻ.');
    }
    for (var offset = 0; offset < days; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset),
          date = learningDateKey(day);
      occupied[date] = [
        ...routine.busyOn(day).map(scheduleRange),
        ...learning.timetable
            .where((l) => l.occursOn(day))
            .map(
              (l) => [scheduleMinute(l.startTime), scheduleMinute(l.endTime)],
            ),
      ];
      used[date] = 0;
    }
    // Locked work is preserved, regardless of whether it would fit a new proposal.
    for (final task in pending.where(
      (t) =>
          t.scheduleLocked &&
          t.scheduledDate != null &&
          t.scheduledTime != null,
    )) {
      final date = task.scheduledDate!;
      if (!occupied.containsKey(date)) continue;
      final start = scheduleMinute(task.scheduledTime!),
          end = start + task.durationMinutes;
      occupied[date]!.add([start, end]);
      used[date] = used[date]! + task.durationMinutes;
    }
    for (final task in pending) {
      if (task.scheduleLocked) {
        deferred.add(
          LearningDeferral(
            taskId: task.id,
            reason: 'Giữ nguyên giờ đã khóa; không tự dời nhiệm vụ.',
            remainingMinutes: 0,
          ),
        );
        continue;
      }
      if (task.durationMinutes < 1) {
        deferred.add(
          LearningDeferral(
            taskId: task.id,
            reason: 'Cần nhập thời lượng thực tế.',
            remainingMinutes: 0,
          ),
        );
        continue;
      }
      if (task.kind == 'learn' &&
          task.topicIds.isNotEmpty &&
          task.topicIds.every(
            (id) => learning.readinessFor(id) == TopicReadiness.confident,
          )) {
        deferred.add(
          LearningDeferral(
            taskId: task.id,
            reason: 'Bạn đã đánh dấu vững; không giao học lại từ đầu. Bài được giao và ôn chủ động vẫn được giữ.',
            remainingMinutes: task.durationMinutes,
          ),
        );
        continue;
      }
      var remaining =
          task.durationMinutes - learning.completedMinutesForTask(task.id);
      if (remaining <= 0) {
        deferred.add(
          LearningDeferral(
            taskId: task.id,
            reason: 'Đã ghi nhận đủ thời gian dự kiến; hãy kiểm tra và tự xác nhận bài đã xong.',
            remainingMinutes: 0,
          ),
        );
        continue;
      }
      final due = deadline(task);
      for (var offset = 0; offset < days && remaining > 0; offset++) {
        final day = DateTime(now.year, now.month, now.day + offset),
            date = learningDateKey(day);
        if (due != null && day.isAfter(due)) break;
        final windows = routine.freeOn(day).map(scheduleRange).toList()
          ..sort((a, b) => a[0].compareTo(b[0]));
        for (final window in windows) {
          var cursor = window[0];
          if (offset == 0 && cursor <= now.hour * 60 + now.minute)
            cursor = now.hour * 60 + now.minute + 1;
          final end = due != null && learningDateKey(due) == date
              ? (due.hour * 60 + due.minute).clamp(0, window[1])
              : window[1];
          while (remaining > 0 && cursor < end) {
            final intervals = occupied[date]!;
            final overlap = intervals
                .where((b) => cursor >= b[0] && cursor < b[1])
                .toList();
            if (overlap.isNotEmpty) {
              cursor = overlap.map((x) => x[1]).reduce((a, b) => a > b ? a : b);
              continue;
            }
            var nextBoundary = end;
            for (final blocked in intervals) {
              if (blocked[0] > cursor && blocked[0] < nextBoundary)
                nextBoundary = blocked[0];
            }
            final pauseCost = blocks.any((b) => b.date == date)
                ? breakMinutes
                : 0;
            final capacity = (budget - used[date]! - pauseCost).clamp(0, 1440);
            final minutes = [
              remaining,
              maxBlockMinutes,
              capacity,
              nextBoundary - cursor,
            ].reduce((a, b) => a < b ? a : b);
            if (minutes < 5 && minutes < remaining) {
              cursor = nextBoundary;
              continue;
            }
            if (minutes <= 0) break;
            final part = (parts[task.id] ?? 0) + 1;
            parts[task.id] = part;
            blocks.add(
              LearningBlock(
                id: '${task.id}_${date}_${cursor}_$part',
                taskId: task.id,
                title: task.title,
                subject: task.subject,
                date: date,
                startTime: learningClock(cursor),
                minutes: minutes,
                part: part,
                reason: switch (task.kind) {
                  'homework' => 'Bài được giao; ưu tiên theo hạn nộp.',
                  'preparation' => 'Chuẩn bị cho buổi học tiếp theo.',
                  'review' => 'Ôn tập chủ động theo phần cần luyện.',
                  _ => 'Tiến độ mục tiêu trong quỹ giờ còn lại.',
                },
              ),
            );
            occupied[date]!.add([
              (cursor - breakMinutes).clamp(0, 1440),
              cursor + minutes + breakMinutes,
            ]);
            used[date] = used[date]! + minutes + pauseCost;
            cursor += minutes;
            remaining -= minutes;
          }
          if (remaining == 0) break;
        }
      }
      if (remaining > 0)
        deferred.add(
          LearningDeferral(
            taskId: task.id,
            reason: due != null
                ? 'Chưa đủ giờ trước hạn; cần điều chỉnh ưu tiên hoặc khối lượng, không tự dời hạn nộp.'
                : 'Chưa đủ giờ trong khoảng lập lịch; nhiệm vụ vẫn được giữ.',
            remainingMinutes: remaining,
          ),
        );
    }
    blocks.sort(
      (a, b) =>
          ('${a.date} ${a.startTime}').compareTo('${b.date} ${b.startTime}'),
    );
    return UnifiedStudyPlan(
      id: 'plan_${now.microsecondsSinceEpoch}',
      contextSignature: signature(
        tasks: tasks,
        routine: routine,
        learning: learning,
        goals: goals,
      ),
      createdAt: now,
      blocks: blocks,
      deferred: deferred,
    );
  }
}
