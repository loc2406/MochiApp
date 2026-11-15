import '../models/mochi_models.dart';

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
  static const _settingsChannel = MethodChannel('mochi/notifications');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
    tzdata.initializeTimeZones();
    await _notificationsPlugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      payload: 'smart:${reminder.key}',
      scheduledDate: tz.TZDateTime.from(reminder.when, tz.UTC),
      androidScheduleMode: await timerScheduleMode(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'mochii_smart_reminders',
          'Nhắc học thông minh',
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
    tzdata.initializeTimeZones();
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

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

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
    tzdata.initializeTimeZones();
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

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String scheduledDate, // YYYY-MM-DD
    required String scheduledTime, // HH:mm
  }) async {
    await init();
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.areNotificationsEnabled() != true) return;

    tzdata.initializeTimeZones();
    final dateParts = scheduledDate.split('-');
    final timeParts = scheduledTime.split(':');
    final y = int.tryParse(dateParts[0]) ?? DateTime.now().year;
    final m = dateParts.length > 1 ? int.tryParse(dateParts[1]) ?? 1 : 1;
    final d = dateParts.length > 2 ? int.tryParse(dateParts[2]) ?? 1 : 1;
    final h = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 19 : 19;
    final min = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 30 : 30;

    final scheduleDt = DateTime(y, m, d, h, min);
    if (!scheduleDt.isAfter(DateTime.now())) return;
    final when = tz.TZDateTime.from(scheduleDt, tz.local);
    final id = taskNotificationId(taskId);

    const androidDetails = AndroidNotificationDetails(
      'mochi_ai_schedule',
      'Lịch học AI cá nhân',
      channelDescription: 'Nhắc nhở học tập theo lịch sinh hoạt do AI sắp xếp',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: 'Đến giờ học cùng Mochi: $title',
        body:
            'Khung giờ rảnh theo lịch sinh hoạt ($scheduledTime). Bắt đầu phiên học ngay nào!',
        scheduledDate: when,
        androidScheduleMode: await timerScheduleMode(),
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: "task:" + taskId,
      );
      debugPrint('SCHEDULED_NOTIFICATION_SUCCESS: $title at $when (id: $id)');
    } catch (e) {
      debugPrint('scheduleTaskReminder error: $e');
      rethrow;
    }
  }

  Future<void> showDailyReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'mochi_daily_channel',
      'Nhắc nhở học tập hàng ngày',
      channelDescription: 'Nhắc nhở duy trì chuỗi học tập',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    try {
      await _notificationsPlugin.show(
        id: 102,
        title: 'Đến giờ học cùng Mochi rồi!',
        body: 'Chỉ cần 25 phút hôm nay để giữ vững ngọn lửa chuỗi ngày học của bạn!',
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }

  // Hẹn giờ chuông báo nền hoàn thành phiên học (chạy ngay cả khi thoát app / khóa màn hình)
  Future<bool> scheduleTimerEndNotification({
    required int secondsFromNow,
    required String taskTitle,
    bool isBreak = false,
  }) async {
    if (!supported) return true;
    await init();
    if (!await notificationsEnabled()) return false;
    try {
      tzdata.initializeTimeZones();
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

  static int taskNotificationId(String taskId) {
    var id = 37;
    for (final c in taskId.codeUnits) {
      id = ((id * 31) + c) & 0x1fffffff;
    }
    return id + 100000;
  }

  Future<void> reconcileTasks(List<TaskModel> tasks) async {
    if (!supported) return;
    await init();
    if (!await notificationsEnabled())
      throw StateError('notifications_disabled');
    final wanted = <int>{};
    for (final t in tasks) {
      if (t.isDone || t.scheduledDate == null || t.scheduledTime == null)
        continue;
      final when = DateTime.tryParse(
        '${t.scheduledDate}T${t.scheduledTime}:00',
      );
      if (when == null || !when.isAfter(DateTime.now())) continue;
      wanted.add(taskNotificationId(t.id));
      await scheduleTaskReminder(
        taskId: t.id,
        title: t.title,
        scheduledDate: t.scheduledDate!,
        scheduledTime: t.scheduledTime!,
      );
    }
    for (final pending
        in await _notificationsPlugin.pendingNotificationRequests()) {
      if ((pending.payload ?? '').startsWith('task:') &&
          !wanted.contains(pending.id)) {
        await _notificationsPlugin.cancel(id: pending.id);
      }
    }
  }
}
