import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/design/mochi_design.dart';
import 'package:mochi_app/features/flashcards/review_screen.dart';

import 'review_journey_test.dart' show makeStore;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scenario in [
    ('light', 390.0, 1.0, 'lavender', 'electricViolet'),
    ('dark', 390.0, 1.0, 'sky', 'cupertinoBlue'),
    ('light', 320.0, 1.7, 'mint', 'cyberAmber'),
    ('light', 1366.0, 1.0, 'peach', 'sunsetCoral'),
  ]) {
    testWidgets(
      'review preview ${scenario.$1} ${scenario.$2} text ${scenario.$3}',
      (tester) async {
        tester.view.physicalSize = Size(scenario.$2, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (const bool.fromEnvironment('PASTEL_CAPTURE')) {
          final loader = FontLoader('Inter');
          for (final weight in [
            'Regular',
            'Medium',
            'SemiBold',
            'Bold',
            'ExtraBold',
          ]) {
            loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
          }
          await loader.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        }
        final store = makeStore();
        store.profile.themeMode = scenario.$1;
        store.profile.backgroundPreset = scenario.$4;
        store.profile.themePreset = scenario.$5;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: store,
            child: MaterialApp(
              theme: MochiTheme.light(
                accent: MochiPresets.accentFor(store.profile.themePreset),
              ),
              darkTheme: MochiTheme.dark(
                accent: MochiPresets.accentFor(store.profile.themePreset),
              ),
              themeMode: MochiTheme.modeFrom(store.profile.themeMode),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scenario.$3)),
                child: child!,
              ),
              home: const RepaintBoundary(
                key: ValueKey('review-preview'),
                child: ReviewScreen(active: true),
              ),
            ),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.text('Công sai là gì?'), findsWidgets);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('PASTEL_CAPTURE')) {
          await expectLater(
            find.byKey(const ValueKey('review-preview')),
            matchesGoldenFile(
              '../docs/previews/review-${scenario.$1}-${scenario.$2.toInt()}.png',
            ),
          );
        }
        expect(find.byIcon(Icons.palette_outlined), findsNothing);
        expect(
          PastelPalette.of(tester.element(find.byType(ReviewScreen))).dark,
          scenario.$1 == 'dark',
        );
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
}
