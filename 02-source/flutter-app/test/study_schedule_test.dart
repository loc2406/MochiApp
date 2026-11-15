import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/services/study_schedule.dart';
void main() {
 test('No overlaps; remaining work moves to next day within budget', () {
  final rows = scheduleStudyDrafts(List.generate(3, (_) => {'durationMinutes': 25}), now: DateTime(2026,11,2,8),start:'19:30',end:'21:30',dailyMinutes:50);
  expect(rows.map((e)=>e['scheduledTime']), ['19:30','20:00','19:30']);
  expect(rows[2]['scheduledDate'], '2026-11-03');
 });
 test('Past times move forward, not tomorrow reminders disguised as today', () {
  final rows = scheduleStudyDrafts([{'durationMinutes':25}],now:DateTime(2026,11,2,22),start:'19:30',end:'21:30',dailyMinutes:50);
  expect(rows.single['scheduledDate'],'2026-11-03');
 });
 test('Oversized task is rejected rather than overflowing free time', () {
  expect(()=>scheduleStudyDrafts([{'durationMinutes':90}],now:DateTime(2026),start:'19:30',end:'20:00',dailyMinutes:30), throwsStateError);
 });
}
