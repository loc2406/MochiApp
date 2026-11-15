import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/models/knowledge_identity.dart';
void main(){
 test('legacy duplicate ids preserve all content and migrate identically across devices',(){
  final data=[{'id':'same','deckId':'d','front':'q1','back':'a1'},
    {'id':'same','deckId':'d','front':'q2','back':'a2'},
    {'id':'same','deckId':'d','front':'q2','back':'a2'}];
  final migrated=repairKnowledgeIds(data);
  expect(migrated.length,3);expect(migrated.map((x)=>x['id']).toSet().length,3);
  expect(migrated.map((x)=>x['front']).toList(),['q1','q2','q2']);
  expect(repairKnowledgeIds(data),migrated);
  expect(repairKnowledgeIds(migrated),migrated);
  expect(data.last['id'],'same');
 });
}
