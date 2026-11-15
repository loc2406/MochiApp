import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/main.dart';
import 'package:mochi_app/core/database/mochi_store.dart';

import 'package:mochi_app/core/services/fcm_service.dart';
import 'package:mochi_app/core/services/notification_service.dart';
import 'package:mochi_app/features/settings/notification_settings_card.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const localChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const messagingChannel = MethodChannel(
    'plugins.flutter.io/firebase_messaging',
  );
  final localCalls = <MethodCall>[];
  final messagingCalls = <MethodCall>[];
  var permission = true;
  var exactPermission = false;
  var failToken = false;

  Future<void> nativeEvent(String method, Object arguments) async {
    final completed = Completer<void>();
    binding.defaultBinaryMessenger.handlePlatformMessage(
      messagingChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) => completed.complete(),
    );
    await completed.future;
    // Native events are broadcast streams; wait for their asynchronous handlers.
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    setupFirebaseCoreMocks();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(localChannel, (
      call,
    ) async {
      localCalls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
          return permission;
        case 'canScheduleExactNotifications':
          return exactPermission;
        case 'requestNotificationsPermission':
          permission = true;
          return true;
        default:
          return null;
      }
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(messagingChannel, (
      call,
    ) async {
      messagingCalls.add(call);
      if (call.method == 'Messaging#getToken') {
        if (failToken) throw PlatformException(code: 'unavailable');
        return {'token': 'test-registration-token'};
      }
      return null;
    });
  });

  setUp(() {
    localCalls.clear();
    messagingCalls.clear();
    permission = true;
    exactPermission = false;
    failToken = false;
  });

  tearDownAll(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(localChannel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      messagingChannel,
      null,
    );
  });

  test('initialization is idempotent, creates FCM channel, and does not prompt for permission', () async {
    final service = NotificationService();
    await Future.wait([service.init(), service.init(), service.init()]);
    expect(localCalls.where((c) => c.method == 'initialize'), hasLength(1));
    expect(
      localCalls.where((c) => c.method == 'createNotificationChannel'),
      hasLength(1),
    );
    expect(
      localCalls.any((c) => c.method == 'requestNotificationsPermission'),
      isFalse,
    );
  });

  test(
    'local test uses the native notification API and monochrome icon',
    () async {
      await NotificationService().showTestNotification();
      final call = localCalls.singleWhere((c) => c.method == 'show');
      expect(call.arguments['id'], 103);
      expect(call.arguments['platformSpecifics']['icon'], 'ic_stat_mochii');
      expect(
        call.arguments['platformSpecifics']['channelId'],
        NotificationService.pushChannelId,
      );
    },
  );

  test(
    'denied permission is reported instead of pretending the test was sent',
    () async {
      permission = false;
      await expectLater(
        NotificationService().showTestNotification(),
        throwsStateError,
      );
      expect(localCalls.any((c) => c.method == 'show'), isFalse);
    },
  );

  test('permission request is an explicit action', () async {
    permission = false;
    expect(await NotificationService().requestPermission(), isTrue);
    expect(
      localCalls.any((c) => c.method == 'requestNotificationsPermission'),
      isTrue,
    );
  });

  test(
    'timer falls back to inexact when special exact-alarm access is missing',
    () async {
      await NotificationService().scheduleTimerEndNotification(
        secondsFromNow: 60,
        taskTitle: 'Toán',
      );
      final call = localCalls.singleWhere((c) => c.method == 'zonedSchedule');
      expect(call.arguments['id'], 9999);
      expect(
        call.arguments['platformSpecifics']['scheduleMode'],
        'inexactAllowWhileIdle',
      );
      expect(call.arguments['platformSpecifics']['fullScreenIntent'], isFalse);
    },
  );

  test(
    'timer uses exact mode only when Android grants exact-alarm access',
    () async {
      exactPermission = true;
      expect(await NotificationService().scheduleTestNotification(), isTrue);
      final call = localCalls.singleWhere((c) => c.method == 'zonedSchedule');
      expect(call.arguments['id'], 104);
      expect(
        call.arguments['platformSpecifics']['scheduleMode'],
        'exactAllowWhileIdle',
      );
    },
  );

  test('timer cancellation targets the same native reminder ID', () async {
    await NotificationService().cancelTimerEndNotification();
    expect(
      localCalls.singleWhere((c) => c.method == 'cancel').arguments['id'],
      9999,
    );
  });

  test(
    'FCM initialization fetches a real registration-token API, not an FID',
    () async {
      await Future.wait([FCMService().init(), FCMService().init()]);
      expect(FCMService().fcmToken, 'test-registration-token');
      expect(FCMService().error, isNull);
      expect(
        messagingCalls.where((c) => c.method == 'Messaging#getToken'),
        hasLength(1),
      );
      expect(
        messagingCalls.any((c) => c.method == 'Messaging#requestPermission'),
        isFalse,
      );
    },
  );

  test('foreground FCM notification is displayed exactly once through the local API', () async {
    await nativeEvent('Messaging#onMessage', {
      'messageId': 'push-test',
      'notification': {
        'title': 'Lịch học mới',
        'body': 'Đến giờ học cùng Mochii',
      },
    });
    final call = localCalls.singleWhere((c) => c.method == 'show');
    expect(call.arguments['title'], 'Lịch học mới');
    expect(call.arguments['body'], 'Đến giờ học cùng Mochii');
  });

  test('data-only messages do not invent a visible alert', () async {
    await nativeEvent('Messaging#onMessage', {
      'messageId': 'data-only',
      'data': {'key': 'value'},
    });
    expect(localCalls.any((c) => c.method == 'show'), isFalse);
  });

  test('token refresh updates the copyable registration token', () async {
    await nativeEvent('Messaging#onTokenRefresh', 'refreshed-token');
    expect(FCMService().fcmToken, 'refreshed-token');
  });

  test('notification tap is captured without displaying it again', () async {
    await nativeEvent('Messaging#onMessageOpenedApp', {
      'messageId': 'opened-push',
    });
    expect(FCMService().lastOpenedMessage?.messageId, 'opened-push');
    expect(localCalls.any((c) => c.method == 'show'), isFalse);
  });

  test('FCM offline failure is visible and retry recovers', () async {
    failToken = true;
    await FCMService().refreshToken();
    expect(FCMService().error, contains('Chưa kết nối Firebase'));
    expect(FCMService().connecting, isFalse);
    failToken = false;
    await FCMService().refreshToken();
    expect(FCMService().error, isNull);
    expect(FCMService().fcmToken, 'test-registration-token');
  });

  testWidgets(
    'first launch requests native permission once without developer UI',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      permission = false;
      final store = MochiStore()
        ..isLoaded = true
        ..isFirstTime = false;
      await tester.pumpWidget(
        MochiApp(store: store, enableNotifications: true),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        localCalls.where((c) => c.method == 'requestNotificationsPermission'),
        hasLength(1),
      );
      expect(find.text('Bật thông báo học tập?'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('mochi_notification_permission_requested_v2'), true);
      await tester.pumpWidget(const SizedBox());
      permission = false;
      final secondStore = MochiStore()
        ..isLoaded = true
        ..isFirstTime = false;
      await tester.pumpWidget(
        MochiApp(store: secondStore, enableNotifications: true),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        localCalls.where((c) => c.method == 'requestNotificationsPermission'),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'notification controls fit a 320px display at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SingleChildScrollView(child: NotificationSettingsCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Thử trên máy'), findsNothing);
        expect(find.text('Thử chạy nền'), findsNothing);
        expect(find.textContaining('FCM'), findsNothing);
        expect(find.textContaining('Firebase'), findsNothing);
        expect(find.text('Cài đặt Android'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
