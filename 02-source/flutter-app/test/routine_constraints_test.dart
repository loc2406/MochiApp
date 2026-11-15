import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/core/services/study_schedule.dart';
void main() {
 test('Weekly busy windows and existing tasks both block assignment', () {
   final rows=scheduleStudyDrafts([{'durationMinutes':20}],now:DateTime(2026,11,2,8),
      start:'19:00',end:'22:00',dailyMinutes:120,
      routine:const DailyRoutine(weeklyFree:{'1':['19:00-22:00']},weeklyBusy:{'1':['19:00-20:00']}),
      existing:[TaskModel(id:'existing',title:'Existing',subject:'Math',durationMinutes:30,scheduledDate:'2026-11-02',scheduledTime:'20:00')]);
   expect(rows.single['scheduledTime'],'20:35');
 });
 test('Date override can explicitly disable a day', () {
   final rows=scheduleStudyDrafts([{'durationMinutes':20}],now:DateTime(2026,11,2,8),
      start:'19:00',end:'22:00',dailyMinutes:60,
      routine:const DailyRoutine(dateFree:{'2026-11-02':[]}));
   expect(rows.single['scheduledDate'],'2026-11-03');
 });
 test('No capacity before deadline returns failure', () {
   expect(()=>scheduleStudyDrafts([{'durationMinutes':20}],now:DateTime(2026,11,2,8),
      start:'19:00',end:'22:00',dailyMinutes:60,horizonDays:1,
      routine:const DailyRoutine(dateFree:{'2026-11-02':[]})), throwsStateError);
 });
 test('Routine roundtrip preserves week, busy and month overrides', () {
   const r=DailyRoutine(weeklyFree:{'1':['09:00-10:00']},dateBusy:{'2026-11-02':['09:00-09:30']});
   expect(DailyRoutine.fromJson(r.toJson()).toJson(),r.toJson());
 });
}
