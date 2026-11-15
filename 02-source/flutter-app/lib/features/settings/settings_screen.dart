import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/services/notification_service.dart';
import '../../design/mochi_design.dart';
import '../../shared/widgets/app_version_caption.dart';
import '../routine/routine_screen.dart';
import 'notification_settings_card.dart';
import 'personalization_card.dart';
import 'smart_reminder_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _importExportCtrl = TextEditingController();

  @override
  void dispose() {
    _importExportCtrl.dispose();
    super.dispose();
  }

  void _handleExport() {
    final store = context.read<MochiStore>();
    final jsonStr = store.exportBackupJson();
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép toàn bộ dữ liệu học tập vào bộ nhớ đệm!'),
      ),
    );
  }

  void _handleImport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nhập bản sao lưu dữ liệu'),
        content: MochiTextField(
          controller: _importExportCtrl,
          hint: 'Dán chuỗi JSON đã xuất từ website hoặc app vào đây...',
          maxLines: 6,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
          MochiPrimaryButton(
            onPressed: () {
              final text = _importExportCtrl.text.trim();
              if (text.isNotEmpty) {
                final success = context.read<MochiStore>().importBackupJson(
                  text,
                );
                Navigator.pop(ctx);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Khôi phục dữ liệu thành công!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: Định dạng dữ liệu không hợp lệ!'),
                    ),
                  );
                }
              }
            },
            child: Text('Khôi phục'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(MochiStore store) {
    MochiDialog.show(
      context,
      title: 'Xác nhận đặt lại?',
      message: 'Hành động này sẽ xóa toàn bộ mục tiêu, nhiệm vụ và tiến độ hiện tại trên thiết bị.',
      confirmLabel: 'Xác nhận xóa',
      icon: Icons.delete_forever_outlined,
      destructive: true,
    ).then((confirmed) {
      if (!confirmed || !mounted) return;
      store.resetAllData();
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);

    return MochiScaffold(
      appBar: MochiAppBar(
        title: 'Cài đặt & Tùy chọn',
        subtitle: 'Không gian học của riêng bạn.',
        large: true,
        actions: [
          MochiIconButton(
            icon: Icons.info_outline,
            tooltip: 'Thông tin ứng dụng',
            onPressed: () => _showAbout(context),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          MochiSpacing.xl,
          MochiSpacing.xs,
          MochiSpacing.xl,
          MochiSpacing.xxl,
        ),
        children: [
          PersonalizationCard(),
          SizedBox(height: MochiSpacing.md),
          NotificationSettingsCard(),
          SizedBox(height: MochiSpacing.md),
          SmartReminderSettings(),
          !NotificationService.supported
              ? const SizedBox.shrink()
              : SizedBox(height: MochiSpacing.md),

          // Weekly/monthly routine calendar.
          MochiCard(
            padding: EdgeInsets.zero,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoutineScreen()),
            ),
            child: MochiListTile(
              icon: Icons.calendar_month_outlined,
              title: 'Lịch sinh hoạt',
              subtitle: 'Chia tuần và tháng theo nhịp học của bạn.',
              showChevron: true,
            ),
          ),
          SizedBox(height: MochiSpacing.md),

          // Display & interaction toggles.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: MochiSpacing.xxs,
                  bottom: MochiSpacing.sm,
                ),
                child: Text(
                  'Hiển thị & Tương tác',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ),
              MochiCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    MochiListTile(
                      icon: Icons.contrast_rounded,
                      title: 'Tương phản cao',
                      subtitle: 'Dùng nền đặc để tăng độ dễ đọc.',
                      trailing: Switch.adaptive(
                        value: store.profile.highContrast,
                        onChanged: (val) {
                          store.profile.highContrast = val;
                          store.save();
                        },
                      ),
                    ),
                    Divider(height: 1, color: palette.cardBorder),
                    MochiListTile(
                      icon: Icons.motion_photos_off_outlined,
                      iconTone: MochiChipTone.medium,
                      title: 'Giảm chuyển động',
                      subtitle: 'Giảm hoạt ảnh khi chuyển trang.',
                      trailing: Switch.adaptive(
                        value: store.profile.reducedMotion,
                        onChanged: (val) {
                          store.profile.reducedMotion = val;
                          store.save();
                        },
                      ),
                    ),
                    Divider(height: 1, color: palette.cardBorder),
                    MochiListTile(
                      icon: Icons.vibration_rounded,
                      iconTone: MochiChipTone.low,
                      title: 'Rung phản hồi',
                      subtitle: 'Rung nhẹ khi chạm nút và chuyển tab.',
                      trailing: Switch.adaptive(
                        value: store.profile.hapticEnabled,
                        onChanged: (val) {
                          store.profile.hapticEnabled = val;
                          store.save();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: MochiSpacing.md),

          if (NotificationService.supported) ...[
            MochiCard(
              padding: EdgeInsets.zero,
              onTap: () => NotificationService().openSystemSettings(),
              child: MochiListTile(
                icon: Icons.volume_up_outlined,
                iconTone: MochiChipTone.neutral,
                title: 'Âm thanh và rung',
                subtitle: 'Tùy chỉnh trên thiết bị',
                showChevron: true,
              ),
            ),
            SizedBox(height: MochiSpacing.md),
          ],

          // Backup & restore.
          // MochiCard(
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Row(
          //         children: [
          //           Container(
          //             width: 42,
          //             height: 42,
          //             decoration: BoxDecoration(
          //               color: palette.softAccent,
          //               borderRadius: BorderRadius.circular(14),
          //             ),
          //             child: Icon(
          //               Icons.folder_zip_outlined,
          //               color: palette.accent,
          //               size: MochiIconSize.md,
          //             ),
          //           ),
          //           SizedBox(width: MochiSpacing.sm),
          //           Expanded(
          //             child: Text(
          //               'Sao lưu & Chuyển dữ liệu',
          //               style: theme.textTheme.titleMedium?.copyWith(
          //                 color: palette.ink,
          //                 fontWeight: FontWeight.w800,
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //       SizedBox(height: MochiSpacing.sm),
          //       NoteButton(
          //         note: 'Xuất bản sao lưu hoặc khôi phục dữ liệu đã lưu. Tài khoản đã đăng nhập tiếp tục đồng bộ khi có mạng.',
          //       ),
          //       SizedBox(height: MochiSpacing.md),
          //       Row(
          //         children: [
          //           Expanded(
          //             child: MochiButton(
          //               label: 'Sao chép dữ liệu',
          //               icon: Icons.copy_rounded,
          //               variant: MochiButtonVariant.secondary,
          //               size: MochiButtonSize.small,
          //               onPressed: _handleExport,
          //             ),
          //           ),
          //           SizedBox(width: MochiSpacing.xs),
          //           Expanded(
          //             child: MochiButton(
          //               label: 'Khôi phục',
          //               icon: Icons.file_upload_outlined,
          //               size: MochiButtonSize.small,
          //               onPressed: _handleImport,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ],
          //   ),
          // ),
          // SizedBox(height: MochiSpacing.md),

          // Reset data.
          MochiCard(
            padding: EdgeInsets.zero,
            onTap: () => _confirmReset(store),
            child: MochiListTile(
              icon: Icons.delete_forever_outlined,
              iconTone: MochiChipTone.danger,
              title: 'Đặt lại dữ liệu',
              subtitle: 'Xóa dữ liệu trên máy và quay về trạng thái ban đầu',
              showChevron: true,
            ),
          ),
          SizedBox(height: MochiSpacing.lg),
          Center(
            child: Text(
              'Mochi-Học cùng nhau',
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: MochiSpacing.xxs),
          Center(child: AppVersionCaption()),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final palette = MochiPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MochiSpacing.xl,
            0,
            MochiSpacing.xl,
            MochiSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: palette.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: palette.onAccent,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: MochiSpacing.sm),
                  Text(
                    'Mochi-Học cùng nhau',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: MochiSpacing.sm),
              Text(
                'Ứng dụng học tập cá nhân: lập kế hoạch, ôn tập ngắt quãng, hỏi AI và giữ nhịp học mỗi ngày.',
                style: Theme.of(ctx).textTheme.bodySmall
                    ?.copyWith(color: palette.muted),
              ),
              SizedBox(height: MochiSpacing.md),
              AppVersionCaption(),
            ],
          ),
        ),
      ),
    );
  }
}
