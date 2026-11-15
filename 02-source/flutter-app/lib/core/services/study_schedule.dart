import '../models/mochi_models.dart';

int scheduleMinute(String value) {
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value))
    throw ArgumentError('Giờ cần dạng HH:mm');
  final p = value.split(':').map(int.parse).toList();
  if (p[0] > 23 || p[1] > 59) throw ArgumentError('Giờ không hợp lệ');
  return p[0] * 60 + p[1];
}

List<int> scheduleRange(String value) {
  final p = value.trim().split('-');
  if (p.length != 2) throw ArgumentError('Khung giờ cần dạng HH:mm-HH:mm');
  final a = scheduleMinute(p[0].trim()), b = scheduleMinute(p[1].trim());
  if (a >= b) throw ArgumentError('Giờ kết thúc phải sau giờ bắt đầu');
  return [a, b];
}

/// AI supplies content; deterministic constraints prevent fabricated availability.
List<Map<String, dynamic>> scheduleStudyDrafts(
  List<Map<String, dynamic>> drafts, {
  required DateTime now,
  required String start,
  required String end,
  required int dailyMinutes,
  DailyRoutine? routine,
  List<TaskModel> existing = const [],
  int horizonDays = 60,
}) {
  final rules =
      routine ??
      DailyRoutine(
        eveningFreeStart: start,
        eveningFreeEnd: end,
        preferredDailyMinutes: dailyMinutes,
      );
  final result = <Map<String, dynamic>>[];
  final occupied = <String, List<List<int>>>{};
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  for (final t in existing) {
    if (t.scheduledDate != null && t.scheduledTime != null && !t.isDone) {
      final a = scheduleMinute(t.scheduledTime!);
      occupied.putIfAbsent(t.scheduledDate!, () => []).add([
        a,
        a + t.durationMinutes + 5,
      ]);
    }
  }
  for (final draft in drafts) {
    final duration = (draft['durationMinutes'] as num?)?.toInt() ?? 25;
    if (duration < 1 || duration > dailyMinutes)
      throw StateError('Nhiệm vụ vượt ngân sách học; cần chia nhỏ.');
    var placed = false;
    for (var offset = 0; offset < horizonDays && !placed; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset),
          date = key(DateTime(now.year, now.month, now.day + offset));
      final free = rules.freeOn(day).map(scheduleRange).toList()
        ..sort((a, b) => a[0].compareTo(b[0]));
      final blocked = [
        ...rules.busyOn(day).map(scheduleRange),
        ...?occupied[date],
      ];
      final used = (occupied[date] ?? []).fold<int>(
        0,
        (sum, r) => sum + r[1] - r[0] - 5,
      );
      if (used + duration > dailyMinutes) continue;
      for (final window in free) {
        var cursor = window[0];
        if (offset == 0) {
          final earliest = now.hour * 60 + now.minute + 1;
          if (cursor < earliest) cursor = earliest;
        }
        while (cursor + duration <= window[1]) {
          final overlaps = blocked
              .where((b) => cursor < b[1] && cursor + duration > b[0])
              .toList();
          if (overlaps.isEmpty) {
            result.add({
              ...draft,
              'scheduledDate': date,
              'scheduledTime':
                  '${(cursor ~/ 60).toString().padLeft(2, '0')}:${(cursor % 60).toString().padLeft(2, '0')}',
            });
            occupied.putIfAbsent(date, () => []).add([
              cursor,
              cursor + duration + 5,
            ]);
            placed = true;
            break;
          }
          cursor = overlaps.map((r) => r[1]).reduce((a, b) => a > b ? a : b);
        }
        if (placed) break;
      }
    }
    if (!placed)
      throw StateError('Không đủ giờ rảnh trước hạn. Chưa lưu kế hoạch.');
  }
  return result;
}
