import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/app_release_info.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/main.dart';
import 'package:mochi_app/shared/widgets/mochii_loading.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('loading fits $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: const MochiiLoadingScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mochii'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'real initialization can stay pending without delaying the first screen',
    (tester) async {
      final store = MochiStore();
      final ready = Completer<void>();
      await tester.pumpWidget(MochiApp(store: store, startup: ready.future));
      expect(find.byType(MochiiLoadingScreen), findsOneWidget);
      expect(find.text('Mochii'), findsOneWidget);
      store.isLoaded = true;
      ready.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(MochiiLoadingScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion stops the decorative animation ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MochiiLoadingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'startup error has a retry action, not an endless pretend progress state',
    (tester) async {
      final failed = Completer<void>();
      var retried = false;
      await tester.pumpWidget(
        MochiApp(
          store: MochiStore(),
          startup: failed.future,
          onStartupRetry: () => retried = true,
        ),
      );
      failed.completeError(StateError('storage_unavailable'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('release metadata is read from the installed Android package', () async {
    const channel = MethodChannel('mochi/notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'appInfo');
          return {'version': '1.2.5', 'build': '2021'};
        });
    final release = await AppReleaseInfo.read();
    expect(release.label, 'Phiên bản 1.2.5 (2021)');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
