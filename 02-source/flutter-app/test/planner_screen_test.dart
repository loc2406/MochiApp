import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Planner FAB clears the nav bar and follows the active tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MochiStore()
      ..isLoaded = true
      ..isFirstTime = false
      ..profile = ProfileModel(name: 'Test');
    store.addGoal(
      'Thi học kỳ',
      DateTime.now().add(const Duration(days: 30)),
      subject: 'Vật lý',
    );

    await tester.pumpWidget(MochiApp(store: store));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Kế hoạch'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Thêm nhiệm vụ'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Thêm nhiệm vụ')).dy,
      lessThan(tester.getTopLeft(find.text('Ôn tập').last).dy),
    );

    await tester.tap(find.text('Mục tiêu lớn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Thêm mục tiêu'), findsOneWidget);
    expect(find.text('Vật lý'), findsWidgets);

    await tester.tap(find.text('Thêm mục tiêu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Thêm mục tiêu lớn'), findsOneWidget);
    expect(find.text('Môn trọng tâm'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
