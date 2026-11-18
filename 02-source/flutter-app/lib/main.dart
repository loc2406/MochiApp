import 'shared/widgets/floating_bar_inset.dart';

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/fcm_service.dart';
import 'core/mochii_bootstrap.dart';
import 'shared/widgets/mochii_loading.dart';
import 'core/services/smart_reminder_service.dart';

import 'package:flutter/rendering.dart';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/database/mochi_store.dart';
import 'design/mochi_design.dart';
import 'core/services/notification_service.dart';
import 'shared/widgets/mochi_icons.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/today/today_screen.dart';
import 'features/planner/planner_screen.dart';
import 'features/ai_tutor/ai_tutor_screen.dart';
import 'features/flashcards/review_screen.dart';
import 'features/profile/profile_calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (FCMService.supported) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(
    MochiiBootstrap(
      appBuilder: (store, startup, status, retry) => MochiApp(
        store: store,
        enableNotifications: true,
        startup: startup,
        startupLabel: status,
        onStartupRetry: retry,
      ),
    ),
  );
}

class MochiApp extends StatelessWidget {
  final MochiVisuals visuals;
  final MochiStore? store;
  final bool enableNotifications;
  final Future<void>? startup;
  final String startupLabel;
  final VoidCallback? onStartupRetry;
  const MochiApp({
    super.key,
    this.store,
    this.visuals = const MochiVisuals(),
    this.enableNotifications = false,
    this.startup,
    this.startupLabel = 'Đang mở dữ liệu học tập…',
    this.onStartupRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => store ?? (MochiStore()..init()),
      child: Consumer<MochiStore>(
        builder: (context, store, _) {
          final accent = MochiPresets.accentFor(store.profile.themePreset);
          final usePhotoBackground =
              store.profile.backgroundPreset == 'image-1';
          final active = visuals.copyWith(
            highContrast: store.profile.highContrast,
            reduceMotion: store.profile.reducedMotion,
            haptics: store.profile.hapticEnabled,
            backdrop: visuals.backdrop.copyWith(
              preset: store.profile.backgroundPreset,
              kind: usePhotoBackground
                  ? MochiBackdropKind.image
                  : MochiBackdropKind.gradient,
              image: usePhotoBackground
                  ? const AssetImage('assets/bg/bg-01.jpg')
                  : null,
            ),
          );
          return MaterialApp(
            title: 'Mochii-Học cùng nhau',
            debugShowCheckedModeBanner: false,
            theme: MochiTheme.light(accent: accent, visuals: active),
            darkTheme: MochiTheme.dark(accent: accent, visuals: active),
            themeMode: store.cloudService.hasActiveUser
                ? MochiTheme.modeFrom(store.profile.themeMode)
                : ThemeMode.light,
            builder: (context, child) => MochiBackground(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations:
                      active.reduceMotion ||
                      MediaQuery.disableAnimationsOf(context),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            themeAnimationDuration: const Duration(milliseconds: 280),
            home: startup == null
                ? RootGate(enableNotifications: enableNotifications)
                : FutureBuilder<void>(
                    future: startup,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return MochiiLoadingScreen(
                          failed: true,
                          onRetry: onStartupRetry,
                          status: 'Chưa mở được ứng dụng. Bạn thử lại nhé.',
                        );
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return MochiiLoadingScreen(status: startupLabel);
                      }
                      return RootGate(enableNotifications: enableNotifications);
                    },
                  ),
          );
        },
      ),
    );
  }
}

class RootGate extends StatefulWidget {
  final bool enableNotifications;
  const RootGate({super.key, this.enableNotifications = false});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  int _currentIndex = 0;
  bool _isBottomBarVisible = true;
  Timer? _barRestore;
  bool _hideBarAtScrollEnd = true;
  bool _notificationPromptChecked = false;

  @override
  void initState() {
    super.initState();
    NotificationService.requestedTab.addListener(_onNotificationTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationTab());
  }

  void _onNotificationTab() {
    final tab = NotificationService.requestedTab.value;
    if (!mounted || tab == null) return;
    NotificationService.requestedTab.value = null;
    _selectTab(tab);
  }

  /// Permission is offered only after onboarding so the system dialog is not
  /// stacked on top of the first-run welcome flow.
  void _maybeOfferNotifications() {
    if (_notificationPromptChecked ||
        !widget.enableNotifications ||
        !NotificationService.supported) {
      return;
    }
    _notificationPromptChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _offerNotifications();
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // ListView dọc của Planner nằm trong PageView của TabBarView nên có thể
    // phát notification ở depth 1. Nhận depth này riêng cho Planner, nhưng
    // bỏ qua các danh sách lồng sâu hơn.
    final maxHandledDepth = _currentIndex == 1 ? 1 : 0;
    if (notification.depth > maxHandledDepth ||
        notification.metrics.axis != Axis.vertical ||
        _currentIndex == 2) {
      return false;
    }

    final metrics = notification.metrics;

    // Ngưỡng cuối trang thay đổi theo kích thước vùng hiển thị.
    final endThreshold = (metrics.viewportDimension * 0.035).clamp(24.0, 56.0);

    final canScroll = metrics.maxScrollExtent > 0;
    final isNearEnd = canScroll && metrics.extentAfter <= endThreshold;

    if (notification is ScrollStartNotification) {
      _barRestore?.cancel();
    }

    if (notification is ScrollUpdateNotification) {
      final dy = notification.scrollDelta ?? 0;

      // Vuốt lên luôn hiện thanh, kể cả khi vẫn còn ở sát cuối danh sách.
      // Trước đây điều kiện isNearEnd chạy trước nên nuốt mất thao tác này.
      if (dy < -4) {
        if (!_isBottomBarVisible) {
          setState(() => _isBottomBarVisible = true);
        }
      } else if (_hideBarAtScrollEnd && isNearEnd) {
        // Dành khoảng trống cho nội dung cuối danh sách khi đang cuộn xuống.
        if (_isBottomBarVisible) {
          setState(() => _isBottomBarVisible = false);
        }
      } else if (dy > 4 && _isBottomBarVisible) {
        // Vuốt xuống.
        setState(() => _isBottomBarVisible = false);
      }
    }

    if (notification is ScrollEndNotification) {
      _barRestore?.cancel();
      // Always restore after scrolling stops, including at the bottom. The
      // bar is hidden only while navigating content, never stranded offscreen.
      _barRestore = Timer(const Duration(milliseconds: 900), () {
        if (mounted && !_isBottomBarVisible) {
          setState(() => _isBottomBarVisible = true);
        }
      });
    }

    return false;
  }

  Future<void> _offerNotifications() async {
    try {
      final service = NotificationService();
      if (await service.notificationsEnabled()) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('mochi_notification_permission_requested_v2') == true ||
          !mounted) {
        return;
      }
      final allowed = await service.requestPermission();
      await prefs.setBool('mochi_notification_permission_requested_v2', true);
      if (allowed) unawaited(SmartReminderService().refresh());
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa bật thông báo. Bạn có thể bật lại trong Tôi > Thông báo để nhận nhắc lịch học.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Notification permission check failed: $e');
    }
  }

  @override
  void dispose() {
    NotificationService.requestedTab.removeListener(_onNotificationTab);
    _barRestore?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();

    if (!store.isLoaded) {
      return const MochiiLoadingScreen();
    }

    if (store.isFirstTime) {
      return OnboardingScreen(
        onComplete: () {
          setState(() {});
        },
      );
    }

    _maybeOfferNotifications();

    final pages = [
      TodayScreen(
        onNavigateToPlanner: () => _selectTab(1),
        onNavigateToAITutor: () => _selectTab(2),
      ),
      const PlannerScreen(),
      AITutorScreen(
        onRequestLogin: () => setState(() {
          _currentIndex = 4;
          _isBottomBarVisible = true;
        }),
      ),
      ReviewScreen(active: _currentIndex == 3),
      const ProfileCalendarScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          // Desktop dashboard: persistent Mochi sidebar + full-width workspace.
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: MochiBackground(
              child: Row(
                children: [
                  _buildDesktopSidebar(context, store),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: pages,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Overlay navigation island architecture:
        // Scaffold acts as a pure full-screen canvas without carving out a dead white strip.
        // FloatingBarInset calculates the exact obstruction for scrollable inner pages.
        final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

        final navVisible = _isBottomBarVisible && !keyboardOpen;

        final barObstruction = MochiNavBar.calculateBottomObstruction(
          context,
          visible: navVisible,
        );

        return Scaffold(
          resizeToAvoidBottomInset: false,
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: MochiBackground(child: SizedBox.expand()),
              ),
              Positioned.fill(
                child: FloatingBarInset(
                  bottomObstruction: barObstruction,
                  isBarVisible: navVisible,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: IndexedStack(index: _currentIndex, children: pages),
                  ),
                ),
              ),
              if (!keyboardOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_isBottomBarVisible,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      offset: _isBottomBarVisible
                          ? Offset.zero
                          : const Offset(0, 2),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isBottomBarVisible ? 1.0 : 0.0,
                        child: _buildFloatingNavBar(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<MochiNavItem> _navItems() => [
    MochiNavItem(
      label: 'Hôm nay',
      iconBuilder: (color) => MochiVectorIcon('home', size: 20, color: color),
    ),
    MochiNavItem(
      label: 'Kế hoạch',
      iconBuilder: (color) => MochiVectorIcon('plan', size: 20, color: color),
    ),
    MochiNavItem(label: 'AI Tutor', icon: Icons.auto_awesome, prominent: true),
    MochiNavItem(
      label: 'Ôn tập',
      iconBuilder: (color) =>
          MochiVectorIcon('flashcard', size: 20, color: color),
    ),
    MochiNavItem(
      label: 'Tôi',
      iconBuilder: (color) =>
          MochiVectorIcon('calendar', size: 20, color: color),
    ),
  ];

  void _selectTab(int index) {
    _barRestore?.cancel();
    setState(() {
      _currentIndex = index;
      _isBottomBarVisible = true;
    });
  }

  Widget _buildDesktopSidebar(BuildContext context, MochiStore store) =>
      MochiSidebar(
        items: _navItems(),
        currentIndex: _currentIndex,
        onSelected: _selectTab,
        userName: store.profile.name,
        userSubtitle: store.cloudService.hasActiveUser
            ? (store.cloudService.userEmail ?? 'Đã đồng bộ')
            : 'Chế độ khách',
        streakLabel: 'Chuỗi ${store.currentStreak} ngày học',
      );

  Widget _buildFloatingNavBar(BuildContext context) => SafeArea(
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: MochiNavBar(
          items: _navItems(),
          currentIndex: _currentIndex,
          onSelected: _selectTab,
        ),
      ),
    ),
  );
}
