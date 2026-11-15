import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/main.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/models/mochi_models.dart';

void main() {
  testWidgets('Bottom bar stays at bottom and Today checkbox accepts taps', (
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
    store.addTask(title: 'Test checkbox', subject: 'Test', duration: 1);
    await tester.pumpWidget(MochiApp(store: store));
    await tester.pump(const Duration(milliseconds: 400));
    final bar = find.text('Hôm nay').last;
    expect(tester.getCenter(bar).dy, greaterThan(700));
    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(checkbox);
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.tasks.single.isDone, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Floating bar returns after scrolling stops', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MochiStore()
      ..isLoaded = true
      ..isFirstTime = false
      ..profile = ProfileModel(name: 'Test');
    for (var i = 0; i < 12; i++) {
      store.addTask(title: 'Task $i');
    }
    await tester.pumpWidget(MochiApp(store: store));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 2),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Planner add action is above the navigation bar and clickable', (
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
    await tester.pumpWidget(MochiApp(store: store));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Kế hoạch'));
    await tester.pump(const Duration(milliseconds: 400));
    final add = find.text('Thêm nhiệm vụ');
    expect(
      tester.getBottomRight(add).dy,
      lessThan(tester.getTopLeft(find.text('Ôn tập').last).dy),
    );
    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Thêm nhiệm vụ học tập'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
