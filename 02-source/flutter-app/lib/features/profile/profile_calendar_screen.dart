import '../../design/mochi_design.dart';
import '../../shared/widgets/floating_bar_inset.dart';
import '../learning/learning_hub_screen.dart';
import '../../core/services/notification_service.dart';
import '../rewards/robot_shop_screen.dart';
import '../auth/auth_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../settings/settings_screen.dart';

class ProfileCalendarScreen extends StatefulWidget {
  const ProfileCalendarScreen({super.key});

  @override
  State<ProfileCalendarScreen> createState() => _ProfileCalendarScreenState();
}

class _ProfileCalendarScreenState extends State<ProfileCalendarScreen> {
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final palette = MochiPalette.of(context);

    return Scaffold(
      backgroundColor: palette.pageTop,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              FloatingBarInset.of(context) + 16,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Zone 2: Profile Card
                _buildProfileCard(context, store, palette),
                const SizedBox(height: 16),

                // Zone 3: Sync Error Banner
                if (store.syncError != null) ...[
                  _buildSyncErrorBanner(context, palette),
                  const SizedBox(height: 16),
                ],

                // Zone 4: Learning Hub Tile
                _buildLearningHubTile(context, store, palette),
                const SizedBox(height: 16),

                // Zone 5: Achievement Statistics
                _buildStatsSection(context, store, palette),
                const SizedBox(height: 16),

                // Zone 6: Monthly Study Calendar
                _buildCalendarCard(context, store, palette),
                const SizedBox(height: 16),

                // Zone 8: Recent Study Journal
                _buildSessionHistory(context, store, palette),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Zone 2: Profile Card (layered)
  Widget _buildProfileCard(
    BuildContext context,
    MochiStore store,
    MochiPalette palette,
  ) {
    return MochiCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: palette.softAccent,
                  child: Text(
                    store.profile.name.isNotEmpty
                        ? store.profile.name[0].toUpperCase()
                        : 'M',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: palette.action,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.profile.name.isNotEmpty
                                    ? store.profile.name
                                    : 'Người học Mochi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: palette.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${store.profile.gradeBand} · Đồng hành: ${store.profile.robotName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.storefront_rounded),
                                tooltip: 'Cửa hàng phụ kiện Robot',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => RobotShopScreen(),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings_outlined),
                                tooltip: 'Cài đặt',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => SettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (store.cloudService.hasActiveUser)
                        Row(
                          children: [
                            Icon(
                              store.isCloudSynced
                                  ? Icons.cloud_done_rounded
                                  : Icons.sync_problem_rounded,
                              size: 14,
                              color: store.isCloudSynced
                                  ? palette.streak
                                  : palette.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                store.cloudService.userEmail ?? 'Đã đồng bộ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: palette.streak,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                await store.cloudService.signOut();
                                store.refreshCloudAuth();
                              },
                              child: Text(
                                'Đăng xuất',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: palette.action, width: 0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => AuthScreen(
                                  isSkippable: true,
                                  onAuthenticated: () {
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.cloud_sync_rounded,
                            size: 14,
                            color: palette.action,
                          ),
                          label: Text(
                            'Đăng nhập đồng bộ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: palette.action,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildStatPill(
                  'Chuỗi kỷ lục',
                  '${store.longestStreak} ngày',
                  Icons.local_fire_department,
                  palette.streak,
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => RobotShopScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildStatPill(
                    'Cửa hàng sao',
                    '${store.stars} sao',
                    Icons.storefront,
                    palette.warning,
                  ),
                ),
                _buildStatPill(
                  'Tổng thời gian',
                  '${store.totalStudyMinutes} phút',
                  Icons.timer,
                  palette.action,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String title, String val, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: paletteInk(context),
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 11, color: paletteMuted(context)),
        ),
      ],
    );
  }

  // Zone 3: Sync Error Banner
  Widget _buildSyncErrorBanner(BuildContext context, MochiPalette palette) {
    return MochiNoticeBanner(
      severity: MochiNoticeSeverity.error,
      title: 'Lỗi đồng bộ',
      message: context.watch<MochiStore>().syncError!,
      actionLabel: 'Thử lại',
      onAction: () => context.read<MochiStore>().init(),
    );
  }

  // Zone 4: Learning Hub Tile
  Widget _buildLearningHubTile(
    BuildContext context,
    MochiStore store,
    MochiPalette palette,
  ) {
    return MochiCard(
      padding: EdgeInsets.zero,
      child: MochiListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: palette.softAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.school_outlined, color: palette.action, size: 22),
        ),
        title: 'Hồ sơ học tập và lịch chung',
        subtitle: 'Quản lý tiến độ từng môn học, bài tập cần làm và thời khóa biểu lên lớp hàng tuần.',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LearningHubScreen()),
        ),
      ),
    );
  }

  // Zone 5: Achievement Statistics
  Widget _buildStatsSection(
    BuildContext context,
    MochiStore store,
    MochiPalette palette,
  ) {
    return MochiCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MochiStatRow(
          children: [
            MochiStatTile(
              label: 'Chuỗi kỷ lục',
              value: '${store.longestStreak}',
              unit: 'ngày',
              icon: Icons.local_fire_department,
              iconTone: MochiChipTone.warning,
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => RobotShopScreen()),
                );
              },
              child: MochiStatTile(
                label: 'Cửa hàng sao',
                value: '${store.stars}',
                unit: 'sao',
                icon: Icons.storefront,
                iconTone: MochiChipTone.warning,
              ),
            ),
            MochiStatTile(
              label: 'Tổng thời gian',
              value: '${store.totalStudyMinutes}',
              unit: 'phút',
              icon: Icons.timer,
              iconTone: MochiChipTone.accent,
            ),
          ],
        ),
      ),
    );
  }

  // Zone 6: Monthly Study Calendar
  Widget _buildCalendarCard(
    BuildContext context,
    MochiStore store,
    MochiPalette palette,
  ) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;

    return MochiCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tháng $month/$year',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: palette.ink,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(year, month - 1, 1);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(year, month + 1, 1);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                  .map(
                    (d) => Text(
                      d,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: palette.muted,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: (firstWeekday - 1) + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) {
                  return const SizedBox.shrink();
                }
                final day = index - (firstWeekday - 1) + 1;
                final dateStr =
                    '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                final hasActivity = store.activityDays[dateStr] ?? false;
                final hasScheduledPlan = store.tasks.any(
                  (t) => t.scheduledDate == dateStr,
                );
                final isToday =
                    (year == DateTime.now().year &&
                    month == DateTime.now().month &&
                    day == DateTime.now().day);

                final Color cellBg = hasScheduledPlan
                    ? palette.action.withValues(alpha: 0.15)
                    : (hasActivity
                          ? palette.streak.withValues(alpha: 0.15)
                          : palette.pageTop);
                final Color cellBorder = hasScheduledPlan
                    ? palette.action
                    : (hasActivity
                          ? palette.streak
                          : (isToday ? palette.warning : palette.cardBorder));

                return InkWell(
                  onTap: () => _showDayScheduleDialog(
                    context,
                    store,
                    dateStr,
                    day,
                    month,
                    year,
                    hasActivity,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cellBorder,
                        width: (hasScheduledPlan || hasActivity || isToday)
                            ? 1.5
                            : 0.8,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: hasActivity && !hasScheduledPlan
                                ? palette.ink
                                : (hasScheduledPlan
                                      ? palette.action
                                      : palette.ink),
                          ),
                        ),
                        if (hasActivity)
                          Positioned(
                            bottom: 1,
                            child: _buildStreakFlameIcon(
                              context,
                              store.streakOn(DateTime(year, month, day)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.action,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Có lịch học',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: palette.action,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.streak,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Đã hoàn thành',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: palette.streak,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 12,
                  color: palette.streak,
                ),
                const SizedBox(width: 2),
                Text(
                  'Cấp độ lửa Streak',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: palette.streak,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Zone 8: Recent Study Journal
  Widget _buildSessionHistory(
    BuildContext context,
    MochiStore store,
    MochiPalette palette,
  ) {
    if (store.sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return MochiCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nhật ký các phiên học gần đây',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: palette.ink,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: palette.action,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...store.sessions.take(5).map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.softAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.timer_outlined,
                        color: palette.action,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.taskTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: palette.ink,
                            ),
                          ),
                          Text(
                            '${s.startedAt.day}/${s.startedAt.month} · ${(s.activeSeconds / 60).round()} phút · Đánh giá: ${s.selfRating}/5',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: palette.warning,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '+${s.earnedStars}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: palette.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Zone 7: Day Detail Bottom Sheet
  void _showDayScheduleDialog(
    BuildContext context,
    MochiStore store,
    String dateStr,
    int day,
    int month,
    int year,
    bool hasActivity,
  ) {
    final dayTasks = store.tasks.where((t) {
      if (t.scheduledDate != null && t.scheduledDate == dateStr) return true;
      final createdStr =
          '${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}-${t.createdAt.day.toString().padLeft(2, '0')}';
      return createdStr == dateStr;
    }).toList();

    final palette = MochiPalette.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch học ngày $day/$month/$year',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasActivity
                          ? 'Ngày này đã có hoạt động học tập'
                          : 'Chưa có hoạt động nào hoàn thành',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasActivity
                        ? palette.streak.withValues(alpha: 0.15)
                        : palette.cardSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasActivity ? 'Đã học' : 'Chưa học',
                    style: TextStyle(
                      color: hasActivity ? palette.streak : palette.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (dayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Không có nhiệm vụ nào được lên lịch cho ngày này.',
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: dayTasks.length,
                  itemBuilder: (ctx, i) {
                    final t = dayTasks[i];
                    final timeLabel = t.scheduledTime ?? 'Buổi tối';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.cardSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.action.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: palette.action,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeLabel,
                                  style: TextStyle(
                                    color: palette.action,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    decoration: t.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  '${t.subject} · ${t.durationMinutes} phút',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.alarm_add_rounded,
                              color: palette.warning,
                              size: 20,
                            ),
                            tooltip: 'Đặt chuông báo giờ học',
                            onPressed: () async {
                              final parts = timeLabel.split(':');
                              final hour = parts.isNotEmpty
                                  ? int.tryParse(parts[0]) ?? 20
                                  : 20;
                              final minute = parts.length > 1
                                  ? int.tryParse(parts[1]) ?? 0
                                  : 0;
                              final reminderDate = DateTime(
                                year,
                                month,
                                day,
                                hour,
                                minute,
                              );
                              if (reminderDate.isAfter(DateTime.now())) {
                                await NotificationService().scheduleLiveReview(
                                  t.id,
                                  'Đến giờ học: ${t.title} (${t.durationMinutes} phút)',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã đặt nhắc nhở lúc $timeLabel ngày $day/$month!',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Giờ đã qua, hãy chọn ngày trong tương lai.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakFlameIcon(BuildContext context, int streak) {
    final palette = MochiPalette.of(context);
    double size = 8.0;
    Color flameColor = palette.streak.withValues(alpha: 0.6);
    if (streak >= 14) {
      size = 14.0;
      flameColor = palette.streak;
    } else if (streak >= 7) {
      size = 12.0;
      flameColor = palette.streak;
    } else if (streak >= 3) {
      size = 10.0;
      flameColor = palette.streak;
    }
    return Icon(
      Icons.local_fire_department_rounded,
      size: size,
      color: flameColor,
    );
  }

  Color paletteInk(BuildContext context) => MochiPalette.of(context).ink;
  Color paletteMuted(BuildContext context) => MochiPalette.of(context).muted;
}
