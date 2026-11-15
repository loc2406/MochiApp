import 'dart:convert';

import '../models/mochi_models.dart';
import '../learning/learning_models.dart';
import 'study_schedule.dart';

class ScheduleChangePolicy {
  static DateTime strictDate(String date) {
    final day = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        day == null ||
        learningDateKey(day) != date) {
      throw StateError('Ngày học cần có dạng YYYY-MM-DD và tồn tại thật.');
    }
    return day;
  }

  static TaskModel validate({
    required Map<String, dynamic> action,
    required List<TaskModel> tasks,
    required DailyRoutine routine,
    required LearningState learning,
    required DateTime now,
    int spentMinutes = 0,
  }) {
    if (action['action'] != 'reschedule_task' ||
        action['taskId'] is! String ||
        action['date'] is! String ||
        action['newTime'] is! String) {
      throw StateError('Đề xuất chưa đủ nhiệm vụ, ngày và giờ.');
    }
    final task = tasks.where((t) => t.id == action['taskId']).firstOrNull;
    if (task == null || task.isDone)
      throw StateError('Nhiệm vụ đã xong hoặc không còn tồn tại.');
    if (task.scheduleLocked)
      throw StateError('Nhiệm vụ đã khóa giờ; mở khóa trong kế hoạch trước.');
    if (action['expectedTask'] != jsonEncode(task.toJson()))
      throw StateError('Nhiệm vụ đã đổi từ lúc đề xuất. Hãy yêu cầu tạo lại.');
    if ((learning.activePlan?.blocks ?? []).any((b) => b.taskId == task.id)) {
      throw StateError(
        'Nhiệm vụ thuộc lịch nhiều phiên. Cần xếp lại lịch chung, không dời riêng cả nhiệm vụ.',
      );
    }
    final day = strictDate(action['date']);
    final start = scheduleMinute(action['newTime']),
        end = start + task.durationMinutes;
    final at = day.add(Duration(minutes: start));
    if (!at.isAfter(now) || end > 1440)
      throw StateError('Chọn giờ trong tương lai và không vượt qua nửa đêm.');
    if (task.dueAt != null &&
        at.add(Duration(minutes: task.durationMinutes)).isAfter(task.dueAt!)) {
      throw StateError('Giờ mới vượt hạn hoàn thành; không tự dời hạn nộp.');
    }
    final free = routine.freeOn(day).map(scheduleRange);
    if (!free.any((r) => start >= r[0] && end <= r[1]))
      throw StateError('Giờ mới nằm ngoài lịch rảnh đã lưu.');
    final blocked = <List<int>>[
      ...routine.busyOn(day).map(scheduleRange),
      for (final lesson in learning.timetable.where((l) => l.occursOn(day)))
        [scheduleMinute(lesson.startTime), scheduleMinute(lesson.endTime)],
      for (final t in tasks.where(
        (t) =>
            t.id != task.id &&
            !t.isDone &&
            t.scheduledDate == action['date'] &&
            t.scheduledTime != null,
      ))
        [
          scheduleMinute(t.scheduledTime!),
          scheduleMinute(t.scheduledTime!) + t.durationMinutes,
        ],
      for (final block in learning.activePlan?.blocks ?? <LearningBlock>[])
        if (block.date == action['date'])
          [
            scheduleMinute(block.startTime),
            scheduleMinute(block.startTime) + block.minutes,
          ],
    ];
    if (blocked.any((r) => start < r[1] && end > r[0]))
      throw StateError(
        'Giờ mới trùng giờ bận, giờ lên lớp hoặc nhiệm vụ khác.',
      );
    final committed = tasks
        .where(
          (t) =>
              t.id != task.id && !t.isDone && t.scheduledDate == action['date'],
        )
        .fold<int>(0, (sum, t) => sum + t.durationMinutes);
    final datedIds = tasks
        .where((t) => t.scheduledDate == action['date'])
        .map((t) => t.id)
        .toSet();
    final planned = (learning.activePlan?.blocks ?? <LearningBlock>[])
        .where((b) => b.date == action['date'] && !datedIds.contains(b.taskId))
        .fold<int>(
          0,
          (sum, b) =>
              sum +
              (b.minutes - learning.completedMinutesForBlock(b.id)).clamp(
                0,
                b.minutes,
              ),
        );
    if (committed + task.durationMinutes + planned + spentMinutes >
        routine.preferredDailyMinutes)
      throw StateError('Ngày này không còn đủ quỹ giờ học.');
    return task;
  }
}
