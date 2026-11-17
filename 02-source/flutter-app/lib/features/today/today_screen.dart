import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../design/mochi_design.dart';
import '../../shared/widgets/floating_bar_inset.dart';
import '../../shared/widgets/mochi_icons.dart';
import '../ai_tutor/ai_tutor_sheet.dart';
import '../focus/focus_timer_screen.dart';
import '../rewards/robot_shop_screen.dart';
import '../robot/robot_mascot_widget.dart';

class TodayScreen extends StatelessWidget {
  final VoidCallback onNavigateToPlanner;
  final VoidCallback? onNavigateToAITutor;

  const TodayScreen({
    super.key,
    required this.onNavigateToPlanner,
    this.onNavigateToAITutor,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final pendingTasks = store.tasks.where((t) => !t.isDone).toList();
    final completedTasks = store.tasks.where((t) => t.isDone).toList();
    final total = store.tasks.length;
    final progressPct = total > 0 ? (completedTasks.length / total) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: MochiPalette.of(context).action,
        onRefresh: () async {
          await store.init();
        },
        child: ListView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            FloatingBarInset.of(context) + 32,
          ),
          children: [
            // 2.1 AppBar – Khu vực chào mừng
            _buildAppBarArea(context, store),
            const SizedBox(height: 16),

            // 2.2 Hero Card – Robot đồng hành
            _buildHeroCard(context, store),
            const SizedBox(height: 20),

            // 2.3 Progress Card – Tiến độ nhiệm vụ
            _buildProgressCard(
              context,
              completedTasks.length,
              total,
              progressPct,
            ),
            const SizedBox(height: 20),

            // 2.4 Task List – Danh sách nhiệm vụ hôm nay
            _buildTaskListHeader(context, store),
            const SizedBox(height: 8),
            if (pendingTasks.isEmpty && completedTasks.isEmpty)
              _buildEmptyState(context)
            else ...[
              ...pendingTasks.map(
                (task) => _buildTaskItem(context, store, task),
              ),
              if (completedTasks.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCompletedTasksSection(context, store, completedTasks),
              ],
            ],
            const SizedBox(height: 18),

            // 2.6 AI Tutor Banner – Hỏi Mochi AI
            _buildAITutorCallout(context, store),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 2.1 AppBar – Khu vực chào mừng
  Widget _buildAppBarArea(BuildContext context, MochiStore store) {
    final palette = MochiPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: palette.cardSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.accent),
      ),
      child: Row(
        children: [
          // Avatar robot hình tròn
          CircleAvatar(
            radius: 28,
            backgroundColor: palette.card.withValues(alpha: 0.15),
            child: MochiVectorIcon(
              'robot',
              size: 28,
              color: Color(store.robotColorHex),
            ),
          ),
          const SizedBox(width: 12),
          // Dòng chào mừng
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chào ${store.profile.name.isNotEmpty ? store.profile.name : "bạn"}!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Học cùng ${store.profile.robotName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.ink.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Chip chuỗi ngày học (bên phải)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.card.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: palette.cardBorder.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: palette.danger,
                  size: 17,
                ),
                const SizedBox(width: 5),
                Text(
                  '${store.currentStreak} ngày',
                  style: TextStyle(
                    color: palette.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2.2 Hero Card – Robot đồng hành
  Widget _buildHeroCard(BuildContext context, MochiStore store) {
    final palette = MochiPalette.of(context);
    List<Widget> buildStats({required bool dense}) => [
      MochiStatTile(
        label: 'XP',
        value: '${store.xp}',
        icon: Icons.bolt_rounded,
        iconTone: MochiChipTone.accent,
        dense: dense,
      ),
      MochiStatTile(
        label: 'Phút học',
        value: '${store.totalStudyMinutes}',
        unit: 'p',
        icon: Icons.schedule_rounded,
        iconTone: MochiChipTone.accent,
        dense: dense,
      ),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => RobotShopScreen()),
          );
        },
        child: MochiStatTile(
          label: 'Cửa hàng',
          value: 'Robot',
          icon: Icons.shopping_bag_outlined,
          iconTone: MochiChipTone.accent,
          dense: dense,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final robotSize = constraints.maxWidth < 360 ? 96.0 : 120.0;
        final stats = buildStats(dense: compact);
        return MochiCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Phần trên: Robot Mascot
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 14 : 20),
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                ),
                child: Center(
                  child: RobotMascotWidget(
                    size: robotSize,
                    emotion: store.robotEmotion,
                    primaryColor: Color(store.robotColorHex),
                    equippedAccessory: store.equippedAccessory,
                    equippedClothes: store.equippedClothes,
                    equippedSpecial: store.equippedSpecial,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      store.setRobotEmotion(RobotEmotion.celebrate);
                    },
                  ),
                ),
              ),
              // Phần dưới: xếp dọc trên màn hẹp để nhãn và giá trị đủ chỗ.
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 10 : 16),
                decoration: BoxDecoration(
                  color: palette.cardSoft.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(26),
                    bottomRight: Radius.circular(26),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: palette.cardBorder.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: compact
                    ? Column(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: palette.cardBorder.withValues(alpha: 0.5),
                              ),
                            stats[i],
                          ],
                        ],
                      )
                    : MochiStatRow(children: stats),
          ),
            ],
          ),
        );
      },
    );
  }

  // 2.3 Progress Card – Tiến độ nhiệm vụ
  Widget _buildProgressCard(
    BuildContext context,
    int done,
    int total,
    double pct,
  ) {
    final pct100 = (pct * 100).toInt();
    final palette = MochiPalette.of(context);
    return MochiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ nhiệm vụ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                  fontSize: 14,
                ),
              ),
              Text(
                '$done / $total',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: palette.action,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: palette.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bạn đã hoàn thành $pct100% nhiệm vụ hôm nay.',
            style: TextStyle(
              fontSize: 12,
              color: palette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 2.4 Task List Header
  Widget _buildTaskListHeader(BuildContext context, MochiStore store) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Nhiệm vụ hôm nay',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: MochiPalette.of(context).ink,
            letterSpacing: -0.2,
          ),
        ),
        TextButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            onNavigateToPlanner();
          },
          icon: Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: MochiPalette.of(context).action,
          ),
          label: Text(
            'Xem tất cả',
            style: TextStyle(
              color: MochiPalette.of(context).action,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // 2.4 Task Item (giữ nguyên logic xử lí)
  Widget _buildTaskItem(
    BuildContext context,
    MochiStore store,
    TaskModel task,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: MochiPalette.of(context).card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            store.toggleTask(task.id, !task.isDone);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: task.isDone
                    ? Colors.transparent
                    : MochiPalette.of(context).cardBorder,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: MochiPalette.of(context).ink.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Checkbox(
                  value: task.isDone,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  activeColor: MochiPalette.of(context).success,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    store.toggleTask(task.id, val ?? false);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: task.isDone
                              ? MochiPalette.of(context).muted
                              : MochiPalette.of(context).ink,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          if (task.scheduledTime != null &&
                              task.scheduledTime!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: MochiPalette.of(context).action
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.scheduledTime!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: MochiPalette.of(context).action,
                                ),
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MochiPalette.of(context).action
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.subject,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MochiPalette.of(context).action,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.durationMinutes} phút',
                            style: TextStyle(
                              fontSize: 12,
                              color: MochiPalette.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!task.isDone)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: MochiPrimaryButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) =>
                                FocusTimerScreen(targetTask: task),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MochiPalette.of(context).accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: MochiPalette.of(context).onAccent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Học ngay',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2.5 Completed Tasks – Nhiệm vụ đã hoàn thành
  Widget _buildCompletedTasksSection(
    BuildContext context,
    MochiStore store,
    List<TaskModel> completedTasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đã hoàn thành (${completedTasks.length})',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MochiPalette.of(context).muted,
          ),
        ),
        const SizedBox(height: 6),
        ...completedTasks.map(
          (task) => _buildCompletedTaskItem(context, store, task),
        ),
      ],
    );
  }

  Widget _buildCompletedTaskItem(
    BuildContext context,
    MochiStore store,
    TaskModel task,
  ) {
    final palette = MochiPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: MochiPalette.of(context).card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            store.toggleTask(task.id, !task.isDone);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.transparent, width: 1.0),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: true,
                  activeColor: palette.accent,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    store.toggleTask(task.id, val ?? false);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.accent,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.subject,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: palette.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.durationMinutes} phút',
                            style: TextStyle(
                              fontSize: 12,
                              color: MochiPalette.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2.4 Empty State
  Widget _buildEmptyState(BuildContext context) {
    return MochiCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            Icons.checklist_rtl_rounded,
            size: 48,
            color: MochiPalette.of(context).action,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có bài tập nào hôm nay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MochiPalette.of(context).ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hãy thêm bài tập mới hoặc để Mochi AI chia nhỏ mục tiêu của bạn!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: MochiPalette.of(context).muted,
            ),
          ),
          const SizedBox(height: 16),
          MochiPrimaryButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              onNavigateToPlanner();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm nhiệm vụ mới'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MochiPalette.of(context).accent,
            ),
          ),
        ],
      ),
    );
  }

  // 2.6 AI Tutor Banner – Hỏi Mochi AI
  Widget _buildAITutorCallout(BuildContext context, MochiStore store) {
    return MochiCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MochiPalette.of(context).card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: MochiPalette.of(context).action
                      .withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: MochiVectorIcon(
              'chat',
              size: 24,
              color: MochiPalette.of(context).action,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gặp bài tập khó?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: MochiPalette.of(context).ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hỏi ngay Mochi AI!',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: MochiPalette.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MochiPrimaryButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              if (onNavigateToAITutor != null) {
                onNavigateToAITutor!();
              } else {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => AITutorSheet(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MochiPalette.of(context).action,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Hỏi AI',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
