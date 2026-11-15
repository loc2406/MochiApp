import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/services/live_bridge_service.dart';
import 'package:mochi_app/design/mochi_design.dart';
import 'package:mochi_app/features/today/today_screen.dart';
import 'package:mochi_app/features/planner/planner_screen.dart';
import 'package:mochi_app/features/ai_tutor/ai_tutor_screen.dart';
import 'package:mochi_app/features/flashcards/review_screen.dart';
import 'package:mochi_app/features/flashcards/flashcards_screen.dart';
import 'package:mochi_app/features/profile/profile_calendar_screen.dart';
import 'package:mochi_app/features/settings/settings_screen.dart';
import 'package:mochi_app/features/routine/routine_screen.dart';
import 'package:mochi_app/features/rewards/robot_shop_screen.dart';
import 'package:mochi_app/features/focus/focus_timer_screen.dart';
import 'package:mochi_app/features/learning/learning_hub_screen.dart';
import 'package:mochi_app/features/auth/auth_screen.dart';
import 'package:mochi_app/features/onboarding/onboarding_screen.dart';
import 'package:mochi_app/features/live_study/live_import_screen.dart';
import 'package:mochi_app/shared/widgets/mochii_loading.dart';

import 'review_journey_test.dart' show makeStore;

Widget app(MochiStore store, Widget page) => ChangeNotifierProvider.value(
  value: store,
  child: Consumer<MochiStore>(
    builder: (context, store, _) {
      final visuals = MochiVisuals(
        reduceMotion: true,
        backdrop: MochiBackdrop(preset: store.profile.backgroundPreset),
      );
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MochiTheme.light(
          accent: MochiPresets.accentFor(store.profile.themePreset),
          visuals: visuals,
        ),
        darkTheme: MochiTheme.dark(
          accent: MochiPresets.accentFor(store.profile.themePreset),
          visuals: visuals,
        ),
        themeMode: MochiTheme.modeFrom(store.profile.themeMode),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: MochiBackground(child: child!),
        ),
        home: RepaintBoundary(
          key: const ValueKey('page'),
          child: MochiBackground(child: page),
        ),
      );
    },
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      font.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final pages = <String, Widget Function()>{
    'today': () => TodayScreen(onNavigateToPlanner: () {}),
    'planner': () => const PlannerScreen(),
    'tutor': () => const AITutorScreen(),
    'review': () => const ReviewScreen(active: true),
    'library': () => const FlashcardsScreen(),
    'profile': () => const ProfileCalendarScreen(),
    'settings': () => const SettingsScreen(),
    'routine': () => const RoutineScreen(),
    'shop': () => const RobotShopScreen(),
    'focus': () => const FocusTimerScreen(),
    'learning': () => const LearningHubScreen(),
    'auth': () => AuthScreen(onAuthenticated: () {}),
    'onboarding': () => OnboardingScreen(onComplete: () {}),
    'live': () => const LiveImportScreen(
      session: LiveSessionImport(
        id: 'preview',
        text: 'Nội dung ôn tập đã lưu.',
        complete: true,
        source: 'Phiên học trực tiếp',
      ),
    ),
    'loading': () => const MochiiLoadingScreen(),
  };
  for (final mode in ['light', 'dark']) {
    for (final entry in pages.entries) {
      testWidgets('${entry.key} uses global $mode Pastel without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = makeStore();
        store.profile.themeMode = mode;
        store.profile.backgroundPreset = 'mint';
        store.profile.name = 'Minh An';
        store.profile.reducedMotion = true;
        await tester.pumpWidget(app(store, entry.value()));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(tester.takeException(), isNull);
        final theme = Theme.of(
          tester.element(find.byKey(const ValueKey('page'))),
        );
        expect(theme.extension<PastelPalette>()?.dark, mode == 'dark');
        expect(theme.extension<MochiVisuals>()?.backdrop.preset, 'mint');
        expect(find.byTooltip('Tùy chỉnh giao diện ôn tập'), findsNothing);
        if (const bool.fromEnvironment('PASTEL_CAPTURE')) {
          await expectLater(
            find.byKey(const ValueKey('page')),
            matchesGoldenFile('../docs/previews/global-${entry.key}-$mode.png'),
          );
        }
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      });
    }
  }
  for (final scenario in [(320.0, 1.7), (1366.0, 1.0)]) {
    for (final entry in pages.entries.where(
      (e) => !['live', 'loading'].contains(e.key),
    )) {
      testWidgets(
        '${entry.key} responsive ${scenario.$1} scale ${scenario.$2}',
        (tester) async {
          tester.view.physicalSize = Size(scenario.$1, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = makeStore();
          store.profile.themeMode = 'light';
          await tester.pumpWidget(
            app(
              store,
              MediaQuery(
                data: MediaQueryData(
                  size: Size(scenario.$1, 1100),
                  textScaler: TextScaler.linear(scenario.$2),
                ),
                child: entry.value(),
              ),
            ),
          );
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          store.dispose();
        },
      );
    }
  }
  testWidgets(
    'background choice in settings updates all routes and keeps accent',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = makeStore();
      store.profile.themeMode = 'light';
      await tester.pumpWidget(app(store, const SettingsScreen()));
      await tester.pump();
      final mint = find.byKey(const ValueKey('background-mint'));
      await tester.ensureVisible(mint);
      await tester.tap(mint);
      await tester.pumpAndSettle();
      expect(store.profile.backgroundPreset, 'mint');
      expect(store.profile.themePreset, 'electricViolet');
      final ctx = tester.element(find.byType(SettingsScreen));
      expect(MochiVisuals.of(ctx).backdrop.preset, 'mint');
      Navigator.of(
        ctx,
      ).push(MaterialPageRoute<void>(builder: (_) => const FlashcardsScreen()));
      await tester.pumpAndSettle();
      expect(
        MochiVisuals.of(tester.element(find.byType(FlashcardsScreen)))
            .backdrop
            .preset,
        'mint',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
