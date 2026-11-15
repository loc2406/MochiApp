import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/features/focus/focus_timer_screen.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
  ]) {
    testWidgets('Visible custom duration, validation and reset at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MochiStore();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(home: FocusTimerScreen()),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final action = find.byKey(const ValueKey('timer-duration'));
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 400));
      final input = find.byKey(const ValueKey('timer-duration-input'));
      await tester.enterText(input, '0');
      await tester.tap(find.text('Áp dụng'));
      await tester.pump();
      expect(find.text('Nhập số phút từ 1 đến 180'), findsOneWidget);
      await tester.enterText(input, '17');
      await tester.tap(find.text('Áp dụng'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('17:00'), findsOneWidget);
      expect(find.text('Đặt thời lượng · 17 phút'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
}
