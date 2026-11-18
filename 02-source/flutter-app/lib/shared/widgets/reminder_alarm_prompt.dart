import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/smart_reminder_service.dart';
import '../../design/mochi_design.dart';

const _promptedKey = 'mochi_exact_alarm_prompted_v1';

/// Asks for Android's "Alarms & reminders" access the first time the learner
/// schedules a task at a specific time.
///
/// Android 13+ denies `SCHEDULE_EXACT_ALARM` by default for new installs, so
/// without this prompt every reminder silently fell back to an inexact alarm
/// and could arrive late while the phone was idle. The prompt is offered once
/// per install; afterwards the notification settings card stays available.
Future<void> offerExactAlarmsForTimedTasks(BuildContext context) async {
  if (!NotificationService.supported) return;
  final notifications = NotificationService();
  try {
    // Without the notification permission itself, exact alarms change nothing.
    if (!await notifications.notificationsEnabled()) return;
    if (await notifications.exactAlarmsEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_promptedKey) == true) return;
    // Mark first so two quick saves cannot show the dialog twice.
    await prefs.setBool(_promptedKey, true);
    if (!context.mounted) return;
    final accepted = await MochiDialog.show(
      context,
      title: 'Nhắc đúng giờ hơn',
      message:
          'Android cần quyền “Báo thức và lời nhắc” để báo nhiệm vụ đúng phút. '
          'Nếu không cấp, lời nhắc có thể đến trễ khi máy đang nghỉ hoặc tiết kiệm pin.',
      icon: Icons.alarm_on_outlined,
      confirmLabel: 'Cho phép',
      cancelLabel: 'Để sau',
    );
    if (!accepted) return;
    await notifications.requestExactAlarms();
    // Reschedule with the new mode: existing alarms were already created as
    // inexact, so they keep their old delivery behaviour until replaced.
    await SmartReminderService().refresh();
  } catch (_) {
    // Permission prompts must never block saving a task.
  }
}
