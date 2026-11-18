import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'smart_reminder_policy.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;

  static const pushChannelId = 'mochii_push_notifications';
  static const pushChannelName = 'Thông báo Mochii';
  static const smartReminderChannelId = 'mochii_smart_reminders';
  static const smartReminderChannelName = 'Nhắc học thông minh';
  static const _settingsChannel = MethodChannel('mochi/notifications');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Tab request produced by tapping a scheduled reminder.
  ///
  /// The root gate listens to this and switches tabs; it stays null when the
  /// learner opens the app normally.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);
  static const plannerTabIndex = 1;

  /// Maps a notification payload to the tab that should open on tap.
  static int? tabForPayload(String? payload) {
    if (payload == null) return null;
    // Only reminders that point at the planner are actionable; pushes keep the
    // previous behaviour of simply opening the app.
    return payload.startsWith('smart:') || payload.startsWith('task:')
        ? plannerTabIndex
        : null;
  }

  static void handleNotificationResponse(String? payload) {
    final tab = tabForPayload(payload);
    if (tab != null) requestedTab.value = tab;
  }

  static bool _timeZonesReady = false;

  /// `initializeTimeZones()` parses the whole tz database, so doing it once per
  /// process is enough; scheduling used to repeat it for every reminder.
  static void _ensureTimeZones() {
    if (_timeZonesReady) return;
    tzdata.initializeTimeZones();
    _timeZonesReady = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> notificationsEnabled() async {
    if (!supported) return false;
    await init();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    await _android?.requestNotificationsPermission();
    return notificationsEnabled();
  }

  Future<bool> exactAlarmsEnabled() async {
    if (!supported) return false;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  Future<bool> requestExactAlarms() async {
    if (!supported) return false;
    await _android?.requestExactAlarmsPermission();
    return exactAlarmsEnabled();
  }

  Future<void> openSystemSettings() async {
    if (supported) await _settingsChannel.invokeMethod<void>('openSettings');
  }

  /// Whether the smart-reminder channel is still enabled at channel level.
  ///
  /// Android lets the learner switch off a single channel while the app-level
  /// notification toggle stays on. In that case scheduling keeps succeeding
  /// but nothing is displayed, so the UI needs this extra check.
  Future<bool> reminderChannelEnabled() async {
    if (!supported) return false;
    try {
      return await _settingsChannel.invokeMethod<bool>('channelEnabled', {
            'channelId': smartReminderChannelId,
          }) ??
          true;
    } catch (_) {
      // Older builds without the native handler keep the previous behaviour.
      return true;
    }
  }

  Future<void> openReminderChannelSettings() async {
    if (!supported) return;
    try {
      await _settingsChannel.invokeMethod<void>('openChannelSettings', {
        'channelId': smartReminderChannelId,
      });
    } catch (_) {
      await openSystemSettings();
    }
  }

  Future<AndroidScheduleMode> timerScheduleMode() async =>
      await exactAlarmsEnabled()
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  Future<void> showPushNotification({
    required int id,
    String? title,
    String? body,
  }) async {
    await init();
    if (!await notificationsEnabled()) return;
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannelId,
          pushChannelName,
          icon: 'ic_stat_mochii',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> showTestNotification() async {
    if (!await notificationsEnabled()) {
      throw StateError('notifications_disabled');
    }
    await showPushNotification(
      id: 103,
      title: 'Mochii-Học cùng nhau',
      body: 'Thông báo trên thiết bị đang hoạt động. Đây là thông báo kiểm tra, không phải push từ Firebase.',
    );
  }

  Future<void> cancelReminder(int id) async {
    if (supported) await _notificationsPlugin.cancel(id: id);
  }

  Future<void> cancelLegacyTaskReminders() async {
    if (!supported) return;
    for (final reminder
        in await _notificationsPlugin.pendingNotificationRequests()) {
      if (reminder.title?.startsWith('Đến giờ học cùng Mochi:') == true) {
        await cancelReminder(reminder.id);
      }
    }
  }

  Future<void> scheduleSmartReminder(PlannedReminder reminder) async {
    await init();
    await _notificationsPlugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      payload: 'smart:${reminder.key}',
      scheduledDate: tz.TZDateTime.from(reminder.when, tz.UTC),
      androidScheduleMode: await timerScheduleMode(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          smartReminderChannelId,
          smartReminderChannelName,
          channelDescription:
              'Nhắc lịch, nhiệm vụ chưa hoàn thành và quay lại học',
          icon: 'ic_stat_mochii',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<bool> scheduleTestNotification() async {
    if (!await notificationsEnabled()) {
      throw StateError('notifications_disabled');
    }
    final mode = await timerScheduleMode();
    await _notificationsPlugin.zonedSchedule(
      id: 104,
      title: 'Mochii nhắc học khi chạy nền',
      body: 'Đây là thông báo kiểm tra đã hẹn trên thiết bị.',
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(const Duration(seconds: 10)),
      androidScheduleMode: mode,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannelId,
          pushChannelName,
          icon: 'ic_stat_mochii',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
    return mode == AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<void> init() {
    if (_initialized || !supported) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    const androidSettings = AndroidInitializationSettings('ic_stat_mochii');
    const initSettings = InitializationSettings(android: androidSettings);
    _ensureTimeZones();

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
          handleNotificationResponse(response.payload);
        },
      );

      // A tap that launches the app cold arrives before the listener exists.
      try {
        final launch = await _notificationsPlugin
            .getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          handleNotificationResponse(launch?.notificationResponse?.payload);
        }
      } catch (_) {
        // Launch details are unavailable on some platform versions.
      }

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          pushChannelId,
          pushChannelName,
          description: 'Thông báo học tập',
          importance: Importance.max,
        ),
      );

      _initialized = true;
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> showTimerComplete({
    required bool isBreak,
    required String taskTitle,
  }) async {
    if (!supported) return;
    await init();
    const androidDetails = AndroidNotificationDetails(
      'mochi_study_timer',
      'Chuông Báo Học Tập',
      channelDescription: 'Thông báo kết thúc phiên tập trung hoặc giờ nghỉ',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      onlyAlertOnce: true,
    );

    final title = isBreak
        ? 'Hết giờ nghỉ ngơi rồi!'
        : 'Hoàn thành phiên tập trung!';
    final body = isBreak
        ? 'Sẵn sàng trở lại phiên học mới cùng Mochi nhé!'
        : 'Bạn đã hoàn thành phiên học: "$taskTitle". Hãy nghỉ ngơi 5 phút!';

    try {
      await _notificationsPlugin.show(
        id: 9999,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> scheduleLiveReview(String sessionId, String reminder) async {
    await init();
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.areNotificationsEnabled() != true) {
      throw StateError('notifications_disabled');
    }
    // Relative 24h scheduling in UTC preserves the intended instant in every device timezone.
    final when = tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 24));
    var id = 17;
    for (final c in sessionId.codeUnits) {
      id = ((id * 31) + c) & 0x3fffffff;
    }
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: 'Ôn lại phiên học',
      body: reminder,
      scheduledDate: when,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'mochi_live_review',
          'Ôn lại phiên học',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  Future<bool> scheduleTimerEndNotification({
    required int secondsFromNow,
    required String taskTitle,
    bool isBreak = false,
  }) async {
    if (!supported) return true;
    await init();
    if (!await notificationsEnabled()) return false;
    try {
      final scheduledDate = tz.TZDateTime.now(tz.local)
          .add(Duration(seconds: secondsFromNow));
      await _notificationsPlugin.zonedSchedule(
        id: 9999,
        title: isBreak ? 'Hết giờ nghỉ ngơi rồi!' : 'Hết giờ học tập trung!',
        body: isBreak
            ? 'Sẵn sàng trở lại phiên học cùng Mochi nhé!'
            : 'Chúc mừng bạn đã hoàn thành phiên học: "$taskTitle". Hãy phản tư và nhận thưởng nhé!',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'mochi_study_timer',
            'Chuông Báo Học Tập',
            channelDescription:
                'Thông báo kết thúc phiên Pomodoro và giờ tự học',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            onlyAlertOnce: true,
          ),
        ),
        androidScheduleMode: await timerScheduleMode(),
      );
      debugPrint('SCHEDULED_TIMER_NOTIFICATION_SUCCESS at $scheduledDate');
      return true;
    } catch (e) {
      debugPrint('scheduleTimerEndNotification error: $e');
      return false;
    }
  }

  Future<void> cancelTimerEndNotification() async {
    if (kIsWeb || !_initialized) return;
    try {
      await _notificationsPlugin.cancel(id: 9999);
    } catch (_) {}
  }
}
