import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/models/knowledge_content.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'account_sync_test.dart';
const explanation='Vật chiếm chỗ trong nước sẽ chịu lực đẩy lên vì áp suất nước ở đáy vật lớn hơn ở phía trên. Lực đẩy bằng trọng lượng nước bị vật chiếm chỗ. Khi tính, cần dùng thể tích phần chìm chứ không phải toàn bộ vật nếu vật chỉ chìm một phần.';
void main(){
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('formula-only content fails prose requirement',(){
  expect(hasKnowledgeExplanation(r'$F_b=\rho gV$'),isFalse);
  expect(hasKnowledgeExplanation(explanation),isTrue);
  expect(hasKnowledgeExplanation(r'$$F=mg$$'),isFalse);
 });
 test('enrichment preserves source and recall history and is reusable',() async {
  var calls=0;
  final store=MochiStore(cloudService:FakeCloud(),aiService:AIService(client:MockClient((req) async {
   calls++;
   expect(req.body,contains('oldAnswer'));
   return http.Response.bytes(utf8.encode(jsonEncode({'choices':[{'finish_reason':'stop','message':{'content':jsonEncode({'explanation':explanation})}}]})),200);
  })));
  store.flashcards=[FlashcardItem(id:'c',deckId:'d',front:'Lực đẩy là gì?',back:r'$F=\rho gV$',repetitions:3)];
  await store.ensureKnowledgeExplanation('c'); await store.ensureKnowledgeExplanation('c');
  expect(calls,1); expect(store.flashcards.single.originalBack,r'$F=\rho gV$');
  expect(store.flashcards.single.repetitions,3);
  expect(FlashcardItem.fromJson(store.flashcards.single.toJson()).back,explanation);
  store.dispose();
 });
 test('formula-only AI output is rejected rather than saved',() async {
  final ai=AIService(client:MockClient((_) async=>http.Response.bytes(utf8.encode(jsonEncode({'choices':[{'finish_reason':'stop','message':{'content':jsonEncode({'explanation':r'$F=mg$'})}}]})),200)));
  await expectLater(ai.explainKnowledgeCard(question:'q',answer:'a',subject:'Vật lý',grade:'11'),throwsFormatException);
 });
}
