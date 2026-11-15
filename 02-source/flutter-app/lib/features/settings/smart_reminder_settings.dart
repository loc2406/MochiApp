import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/smart_reminder_service.dart';
import '../../design/mochi_design.dart';

class SmartReminderSettings extends StatelessWidget {
  const SmartReminderSettings({super.key});

  @override
  Widget build(BuildContext context) {
    if (!NotificationService.supported) return const SizedBox.shrink();
    final service = SmartReminderService();
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => MochiCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MochiListTile(
              icon: Icons.auto_awesome_outlined,
              iconTone: MochiChipTone.accent,
              title: 'Nhắc học thông minh',
              subtitle:
                  'Đến lịch, nhiệm vụ chưa xong và lâu chưa học hoặc mở app.',
              trailing: Switch.adaptive(
                value: service.enabled,
                onChanged: (value) => unawaited(service.setEnabled(value)),
              ),
            ),
            Divider(height: 1, color: palette.cardBorder),
            MochiListTile(
              icon: Icons.edit_note_rounded,
              iconTone: MochiChipTone.medium,
              title: 'AI soạn lời nhắc',
              subtitle: 'Soạn khi có mạng, lưu trên máy để dùng khi ngoại tuyến. Không gửi tên hoặc nội dung nhiệm vụ cho AI.',
              trailing: Switch.adaptive(
                value: service.aiEnabled,
                onChanged: service.enabled
                    ? (value) => unawaited(service.setAIEnabled(value))
                    : null,
              ),
            ),
            Divider(height: 1, color: palette.cardBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MochiSpacing.lg,
                MochiSpacing.md,
                MochiSpacing.lg,
                MochiSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhắc đúng giờ cho từng nhiệm vụ đã lên lịch. Lời nhắc động viên thêm tối đa 2 lần/ngày, cách nhau 3 giờ và không gửi trong 22:00–08:00.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: MochiSpacing.xs),
                  Text(
                    'Lịch nhắc được chuẩn bị trước 7 ngày, tự cập nhật khi bạn đổi lịch, đồng bộ hoặc hoàn thành nhiệm vụ.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: MochiSpacing.sm),
                  MochiChip(
                    label: service.preparingCopy
                        ? 'Đang nhờ AI soạn nội dung…'
                        : service.copySource == 'ai'
                        ? 'Nội dung: AI soạn, đã lưu trên máy.'
                        : 'Nội dung: mẫu theo quy tắc; chưa có nội dung AI khả dụng.',
                    tone: service.copySource == 'ai'
                        ? MochiChipTone.success
                        : MochiChipTone.neutral,
                    compact: true,
                  ),
                  if (service.statusError != null) ...[
                    const SizedBox(height: MochiSpacing.xs),
                    MochiNoticeBanner(
                      message: service.statusError!,
                      severity: MochiNoticeSeverity.error,
                      compact: true,
                    ),
                  ],
                  const SizedBox(height: MochiSpacing.sm),
                  if (service.scheduled.isNotEmpty) ...[
                    Text(
                      'Lời nhắc tiếp theo: ${DateFormat('dd/MM HH:mm').format(service.scheduled.first.when)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MochiSpacing.xxs),
                    Text(
                      service.scheduled.first.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.ink,
                      ),
                    ),
                  ] else
                    Text(
                      'Chưa có lời nhắc đã hẹn. Cần bật quyền thông báo và hoàn thành thiết lập hồ sơ.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  if (service.enabled && service.aiEnabled)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: service.preparingCopy
                            ? null
                            : () => unawaited(service.refresh(forceAI: true)),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Soạn lại lời nhắc'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
