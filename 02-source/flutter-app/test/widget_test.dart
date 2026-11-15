import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/main.dart';

void main() {
  testWidgets('MochiApp loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const MochiApp());
    expect(find.byType(MochiApp), findsOneWidget);
  });
}
