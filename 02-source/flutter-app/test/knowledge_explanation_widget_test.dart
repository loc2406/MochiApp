import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:mochi_app/features/flashcards/knowledge_explanation.dart';
void main(){
 for(final scale in [1.0,2.0]) {
 testWidgets('meaning and example precede optional formula at scale $scale',(tester) async {
 tester.view.physicalSize=const Size(320,900);tester.view.devicePixelRatio=1;
 addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
 await tester.pumpWidget(MaterialApp(home:MediaQuery(data:MediaQueryData(size:const Size(320,900),textScaler:TextScaler.linear(scale)),
 child:const Scaffold(body:SingleChildScrollView(child:Padding(padding:EdgeInsets.all(16),child:KnowledgeExplanation(
 text:r'Một vật ở trong nước chịu lực đẩy lên do áp suất nước phía dưới lớn hơn phía trên. $F=\rho gV$ Các ký hiệu gồm lực, mật độ và thể tích. Ví dụ: một khối gỗ nhẹ có thể nổi trên nước.'
 )))))));
 expect(find.text('Hiểu đơn giản'),findsOneWidget);
 expect(find.byType(Math),findsNothing);
 expect(find.textContaining('Các ký hiệu'),findsNothing);
 expect(tester.takeException(),isNull);
 final expand=find.text('Công thức, ký hiệu và điều kiện');
 await tester.ensureVisible(expand);await tester.tap(expand);await tester.pump(const Duration(milliseconds:400));
 expect(find.byType(Math),findsWidgets);
 expect(tester.takeException(),isNull);
 });
 }
}
