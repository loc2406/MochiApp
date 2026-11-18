import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/smart_reminder_service.dart';
import '../../design/mochi_design.dart';

class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard>
    with WidgetsBindingObserver {
  final _local = NotificationService();
  bool _enabled = false;
  bool _exact = false;
  bool _channelEnabled = true;
  bool _loaded = false;
  bool _busy = false;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reload());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reload());
  }

  Future<void> _reload() async {
    if (!NotificationService.supported) return;
    try {
      final enabled = await _local.notificationsEnabled();
      final exact = await _local.exactAlarmsEnabled();
      final channelEnabled = await _local.reminderChannelEnabled();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _exact = exact;
        _channelEnabled = channelEnabled;
        _loaded = true;
        _statusError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _statusError = 'Chưa đọc được trạng thái thông báo. Hãy thử lại.',
        );
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _reload();
      await SmartReminderService().refresh();
    } catch (_) {
      _message(
        'Chưa thực hiện được. Kiểm tra quyền thông báo trong Cài đặt Android rồi thử lại.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);

    if (!NotificationService.supported) {
      return MochiCard(
        child: Text(
          'Nhắc học và báo hết giờ được hỗ trợ trong ứng dụng Android.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    final status =
        _statusError ??
        (!_loaded
            ? 'Đang kiểm tra quyền…'
            : !_enabled
            ? 'Thông báo đang bị tắt'
            : !_channelEnabled
            ? 'Kênh nhắc học đang bị tắt'
            : 'Đã bật thông báo trên thiết bị');

    return MochiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: palette.warning,
                  size: MochiIconSize.md,
                ),
              ),
              const SizedBox(width: MochiSpacing.sm),
              Expanded(
                child: Text(
                  'Thông báo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_enabled && _channelEnabled)
                MochiChip(
                  label: 'Đang bật',
                  tone: MochiChipTone.success,
                  compact: true,
                )
              else if (_enabled)
                MochiChip(
                  label: 'Kênh bị tắt',
                  tone: MochiChipTone.warning,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: MochiSpacing.md),
          Text(
            status,
            style: theme.textTheme.titleSmall?.copyWith(
              color: _statusError != null
                  ? palette.danger
                  : _enabled && !_channelEnabled
                  ? palette.warning
                  : palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: MochiSpacing.xxs),
          Text(
            'Nhận nhắc nhở theo lịch học và báo khi kết thúc phiên tập trung.',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: MochiSpacing.md),
          Wrap(
            spacing: MochiSpacing.xs,
            runSpacing: MochiSpacing.xs,
            children: [
              if (!_enabled)
                MochiButton(
                  label: 'Bật thông báo',
                  icon: Icons.notifications_active_outlined,
                  size: MochiButtonSize.small,
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final allowed = await _local.requestPermission();
                          if (!allowed) {
                            _message(
                              'Quyền chưa được cấp. Chọn “Cài đặt Android” để bật lại.',
                            );
                          }
                        }),
                ),
              MochiButton(
                label: 'Cài đặt Android',
                icon: Icons.settings_outlined,
                variant: MochiButtonVariant.secondary,
                size: MochiButtonSize.small,
                onPressed: _busy ? null : () => _run(_local.openSystemSettings),
              ),
            ],
          ),
          if (_enabled && !_channelEnabled) ...[
            const SizedBox(height: MochiSpacing.sm),
            MochiNoticeBanner(
              message: 'Kênh “Nhắc học thông minh” đang bị tắt nên mọi lời nhắc sẽ không hiện ra.',
              severity: MochiNoticeSeverity.error,
              compact: true,
              actionLabel: 'Mở kênh',
              onAction: _busy
                  ? null
                  : () => _run(_local.openReminderChannelSettings),
            ),
          ],
          const SizedBox(height: MochiSpacing.md),
          MochiNoticeBanner(
            message: _exact ? 'Nhắc giờ: đã cấp quyền báo thức chính xác.' : 'Nhắc giờ: Android có thể trì hoãn. Cho phép báo thức chính xác để nhắc sát giờ hơn.',
            severity: _exact
                ? MochiNoticeSeverity.success
                : MochiNoticeSeverity.warning,
            icon: _exact ? Icons.alarm_on_outlined : Icons.alarm_outlined,
            compact: true,
          ),
          if (!_exact)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await _local.requestExactAlarms();
                      }),
                child: const Text('Cho phép báo thức chính xác'),
              ),
            ),
        ],
      ),
    );
  }
}
