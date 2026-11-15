import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/main.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/models/mochi_models.dart';

void main() {
  testWidgets('Tutor keyboard resizes once and composer has no doubled bottom gap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final store = MochiStore()
      ..isLoaded = true
      ..isFirstTime = false
      ..profile = ProfileModel(name: 'Test');
    await tester.pumpWidget(MochiApp(store: store));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('AI Tutor').last);
    await tester.pump(const Duration(milliseconds: 400));
    final send = find.byTooltip('Gửi câu hỏi');
    // One navigation reservation, not another 90px inside the tutor page.
    expect(tester.getCenter(send).dy, greaterThan(660));
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getCenter(send).dy, greaterThan(450));
    expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(544));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getCenter(send).dy, greaterThan(660));
    await tester.pumpWidget(const SizedBox());
  });
}
