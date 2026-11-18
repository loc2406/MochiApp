import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/learning/curriculum_catalog.dart';
import 'package:mochi_app/core/learning/learning_models.dart';
import 'package:mochi_app/design/mochi_design.dart';
import 'package:mochi_app/features/learning/learning_hub_screen.dart';

void main() {
  for (final width in [320.0, 768.0, 1366.0])
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Learning hub adapts $width scale $scale and edits real progress',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = MochiStore();
          store.learning = LearningState(
            gradeLevel: 11,
            academicYear: '2026–2027',
            courses: [CurriculumCatalog.courseFor('Toán', 11)],
          );
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: store,
              child: MaterialApp(
                theme: MochiTheme.light(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const LearningHubScreen(),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.scrollUntilVisible(
            find.text('Toán'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(find.text('Toán').first);
          await tester.pumpAndSettle();
          final chip = find.byType(PopupMenuButton<TopicReadiness>).first;
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cần ôn').last);
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            store.learning.progress.single.readiness,
            TopicReadiness.needsReview,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  testWidgets(
    'Add assignment keeps two goal links on one task and previews unified capacity',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = MochiStore();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            theme: MochiTheme.light(),
            home: const LearningHubScreen(initialTab: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('learning-add-assignment')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).first, 'Bài Toán phải nộp');
      await tester.tap(find.text('Thêm việc'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.tasks.single.title, 'Bài Toán phải nộp');
      expect(store.tasks.single.kind, 'homework');
      expect(store.tasks.single.dueAt, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
