import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/features/settings/personalization_card.dart';
import 'package:mochi_app/shared/widgets/note_button.dart';

void main() {
  testWidgets('personalization uses concise copy and opens contextual note', (tester) async {
    final store = MochiStore()..isLoaded = true;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: store,
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PersonalizationCard()))),
    ));
    expect(find.text('Sắc màu chủ đạo'), findsOneWidget);
    expect(find.textContaining('Apple'), findsNothing);
    expect(find.textContaining('Liquid Glass'), findsNothing);
    expect(find.textContaining('Tùy chỉnh sắc màu chủ đạo'), findsNothing);
    await tester.tap(find.byType(NoteButton).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tùy chỉnh sắc màu chủ đạo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
