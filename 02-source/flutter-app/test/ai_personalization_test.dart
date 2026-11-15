import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
void main() {
 test('Flashcard request asks for understanding, conditions and examples', () async {
   String prompt='';
   final service=AIService(client:MockClient((r) async {
     prompt=jsonDecode(r.body)['messages'].last['content'] as String;
     return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode([{'front':'Vì sao cần điều kiện?','back':'Giải thích điều kiện và ví dụ.'}])}}]}),200,headers:{'content-type':'application/json; charset=utf-8'});
   }));
   final cards=await service.generateFlashcardsForTopic(topic:'Định lý',subject:'Toán');
   expect(prompt,contains('bản chất'));expect(prompt,contains('điều kiện'));expect(prompt,contains('ví dụ'));
   expect(cards.single['back'],contains('điều kiện'));
 });
 test('Planner receives user routine and validates AI schedule', () async {
   String prompt='';
   final service=AIService(client:MockClient((r) async {
     prompt=jsonDecode(r.body)['messages'].last['content'] as String;
     return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode([
       {'title':'Bài A','durationMinutes':20,'scheduledTime':'19:30'},
       {'title':'Bài B','durationMinutes':20,'scheduledTime':'19:30'}
     ])}}]}),200,headers:{'content-type':'application/json; charset=utf-8'});
   }));
   const routine=DailyRoutine(weeklyFree:{
     '1':['09:00-11:00'],'2':['09:00-11:00'],'3':['09:00-11:00'],
     '4':['09:00-11:00'],'5':['09:00-11:00'],'6':['09:00-11:00'],'7':['09:00-11:00']
   });
   final rows=await service.breakDownGoalIntoTasks(goalTitle:'Mục tiêu cá nhân',subject:'Lý',totalDays:30,dailyMinutes:60,routine:routine);
   expect(prompt,contains('weeklyFree'));expect(prompt,contains('09:00-11:00'));
   expect(rows[0]['scheduledTime'],isNot(rows[1]['scheduledTime']));
 });
 test('Planner unavailable returns a labelled offline template, not AI output', () async {
   final service=AIService(client:MockClient((_) async=>http.Response('unavailable',503)));
   final drafts=await service.breakDownGoalIntoTasks(goalTitle:'A',subject:'Lý',totalDays:2,dailyMinutes:45);
   expect(drafts,isNotEmpty);
   expect(drafts.every((d)=>d['source']=='offline_template'),isTrue);
   expect(drafts.any((d)=>d['source']=='ai_cloud'),isFalse);
 });
}
