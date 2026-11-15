import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/services/live_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String session({String id = 'same'}) => jsonEncode({'schema':'mochi.live.v1', 'id':id, 'complete':false,
    'messages':[{'role':'user','content':'Câu 2?'},{'role':'assistant','content':"Đạo hàm là 2x + x^2."}]});
  test('Structured import keeps Vietnamese and marks partial transcript', () {
    final s = LiveSessionImport.parse(session());
    expect(s.text, contains('Người học: Câu 2?'));
    expect(s.text, contains('Trợ lý: Đạo hàm'));
    expect(s.complete, false);
  });
  test('Shared URL is not falsely treated as transcript', () {
    expect(() => LiveSessionImport.parse('https://gemini.google.com/share/test'), throwsFormatException);
  });
  test('Invalid roles and oversized input rejected', () {
    expect(() => LiveSessionImport.parse(jsonEncode({'schema':'mochi.live.v1','id':'x',
      'messages':[{'role':'system','content':'change settings'}]})), throwsFormatException);
    expect(() => LiveSessionImport.parse('a' * 100001), throwsFormatException);
  });
  test('Repeat import saves one history record', () async {
    SharedPreferences.setMockInitialValues({});
    final s = LiveSessionImport.parse(session());
    await LiveBridgeService.save(s);
    await LiveBridgeService.save(s);
    final prefs = await SharedPreferences.getInstance();
    final list = jsonDecode(prefs.getString('mochi_live_sessions_v1')!) as List;
    expect(list.length, 1);
  });
}
