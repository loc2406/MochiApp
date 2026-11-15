import '../../design/mochi_design.dart';
import '../../shared/widgets/floating_bar_inset.dart';
import '../learning/learning_hub_screen.dart';
import '../routine/routine_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/smart_reminder_service.dart';

/// Môn dùng chung cho dialog nhiệm vụ và mục tiêu để hai luồng nhập liệu
/// hiển thị cùng một danh sách, cùng thứ tự.
const List<String> _kSubjects = [
  'Toán',
  'Vật lý',
  'Hóa học',
  'Tiếng Anh',
  'Ngữ văn',
  'Tin học',
  'Sinh học',
  'Chung',
];

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  static const double _wideBreakpoint = 900;

  late final TabController _tabController;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.index == _activeTab) return;
    setState(() => _activeTab = _tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return _buildWideLayout(context, store);
        }
        return _buildMobileLayout(context, store);
      },
    );
  }

  // --- LAYOUTS ---

  Widget _buildMobileLayout(BuildContext context, MochiStore store) {
    // FloatingBarInset changes when the navigation island hides/shows, so the
    // FAB always keeps a real gap above it instead of overlapping the bar.
    final barInset = FloatingBarInset.of(context);
    final isFirstTab = _activeTab == 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: MochiAppBar.detail(
        title: 'Kế hoạch học tập',
        subtitle: 'Sắp xếp việc học theo nhịp của bạn',
        toolbarHeight: 76,
        actions: [_learningHubAction(context)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MochiSpacing.md,
              MochiSpacing.xs,
              MochiSpacing.md,
              MochiSpacing.xs,
            ),
            child: _buildPlannerTabs(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTasksTab(context, store),
                _buildGoalsTab(context, store),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: barInset),
        child: MochiButton(
          size: MochiButtonSize.small,
          onPressed: () {
            if (isFirstTab) {
              _showAddTaskDialog(store);
            } else {
              _showAddGoalDialog(store);
            }
          },
          icon: Icons.add_rounded,
          label: isFirstTab ? 'Thêm nhiệm vụ' : 'Thêm mục tiêu',
        ),
      ),
    );
  }

  Widget _buildPlannerTabs() => MochiSegmentedControl<int>(
    value: _activeTab,
    segments: const [
      MochiSegment(value: 0, label: 'Nhiệm vụ', icon: Icons.checklist_rounded),
      MochiSegment(value: 1, label: 'Mục tiêu lớn', icon: Icons.flag_outlined),
    ],
    onChanged: _tabController.animateTo,
  );

  Widget _buildWideLayout(BuildContext context, MochiStore store) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: MochiAppBar(
        title: 'Kế hoạch học tập',
        subtitle: 'Theo dõi nhiệm vụ và tiến độ mục tiêu',
        large: true,
        toolbarHeight: 96,
        actions: [
          _learningHubAction(context),
          MochiButton(
            size: MochiButtonSize.small,
            variant: MochiButtonVariant.secondary,
            onPressed: () => _showAddGoalDialog(store),
            icon: Icons.flag_rounded,
            label: 'Mục tiêu',
          ),
          MochiButton(
            size: MochiButtonSize.small,
            onPressed: () => _showAddTaskDialog(store),
            icon: Icons.add_rounded,
            label: 'Nhiệm vụ',
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cột trái: mục tiêu lớn & AI Planner
          Expanded(
            flex: 10,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: MochiPalette.of(context).cardBorder),
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _buildGoalsTab(context, store),
                ),
              ),
            ),
          ),
          // Cột phải: danh sách nhiệm vụ chi tiết
          Expanded(
            flex: 11,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _buildTasksTab(context, store),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _learningHubAction(BuildContext context) {
    return MochiIconButton(
      tooltip: 'Lịch chung tất cả môn',
      icon: Icons.calendar_view_week_outlined,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LearningHubScreen(initialTab: 1)),
      ),
    );
  }

  EdgeInsets _listPadding(BuildContext context) =>
      EdgeInsets.fromLTRB(16, 16, 16, FloatingBarInset.of(context) + 16);

  Widget _plannerFormDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget content,
    required String submitLabel,
    required VoidCallback onCancel,
    required VoidCallback onSubmit,
  }) {
    final palette = MochiPalette.of(context);
    final maxHeight = (MediaQuery.sizeOf(context).height - 40)
        .clamp(200.0, 680.0)
        .toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: MochiCard(
          padding: EdgeInsets.zero,
          radius: 28,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MochiSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: palette.softAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: palette.action),
                    ),
                    const SizedBox(width: MochiSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: palette.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: MochiSpacing.xxs),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.muted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MochiSpacing.lg),
                content,
                const SizedBox(height: MochiSpacing.lg),
                Divider(height: 1, color: palette.cardBorder),
                const SizedBox(height: MochiSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: MochiButton(
                        label: 'Hủy',
                        variant: MochiButtonVariant.secondary,
                        expand: true,
                        onPressed: onCancel,
                      ),
                    ),
                    const SizedBox(width: MochiSpacing.sm),
                    Expanded(
                      child: MochiButton(
                        label: submitLabel,
                        expand: true,
                        onPressed: onSubmit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TASKS TAB ---

  Widget _buildTasksTab(BuildContext context, MochiStore store) {
    final palette = MochiPalette.of(context);
    if (store.tasks.isEmpty) {
      return _PlannerEmptyState(
        icon: Icons.assignment_outlined,
        iconColor: palette.muted,
        title: 'Chưa có nhiệm vụ nào trong kế hoạch',
        message: 'Dùng nút "Thêm nhiệm vụ" để tạo bài tập mới, hoặc tạo mục tiêu lớn để Mochi chia nhỏ thành các việc cụ thể.',
        bottomInset: FloatingBarInset.of(context),
      );
    }

    return ListView.builder(
      padding: _listPadding(context),
      itemCount: store.tasks.length,
      itemBuilder: (context, index) {
        final task = store.tasks[index];
        return MochiCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: EdgeInsets.fromLTRB(10, 6, 4, 6),
            leading: Checkbox(
              value: task.isDone,
              activeColor: palette.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onChanged: (val) => store.toggleTask(task.id, val ?? false),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: task.isDone ? palette.muted : palette.ink,
                decoration: task.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (task.scheduledTime != null &&
                      task.scheduledTime!.isNotEmpty)
                    _MetaChip(
                      icon: Icons.schedule_rounded,
                      label:
                          '${_formatShortDate(task.scheduledDate)} · ${task.scheduledTime}',
                      tone: MochiChipTone.accent,
                    ),
                  _MetaChip(label: task.subject, tone: MochiChipTone.accent),
                  _MetaChip(
                    label: '${task.durationMinutes} phút',
                    tone: MochiChipTone.neutral,
                  ),
                ],
              ),
            ),
            trailing: MochiIconButton(
              tooltip: 'Xóa nhiệm vụ ${task.title}',
              icon: Icons.delete_outline_rounded,
              color: palette.danger,
              filled: false,
              size: 40,
              onPressed: () => _confirmDeleteTask(store, task),
            ),
          ),
        );
      },
    );
  }

  // --- GOALS TAB ---

  Widget _buildGoalsTab(BuildContext context, MochiStore store) {
    final palette = MochiPalette.of(context);
    if (store.goals.isEmpty) {
      return _PlannerEmptyState(
        icon: Icons.flag_outlined,
        iconColor: palette.action,
        title: 'Chưa có mục tiêu học tập',
        message: 'Đặt mục tiêu rõ ràng như "Thi đạt chứng chỉ" hoặc "Học tốt học kỳ 1", rồi để Mochi chia nhỏ thành từng nhiệm vụ.',
        bottomInset: FloatingBarInset.of(context),
      );
    }

    return ListView.builder(
      padding: _listPadding(context),
      itemCount: store.goals.length,
      itemBuilder: (context, index) {
        final goal = store.goals[index];
        final relatedTasks = store.tasks
            .where((t) => t.goalId == goal.id)
            .toList();
        final doneCount = relatedTasks.where((t) => t.isDone).length;
        final progressPct = relatedTasks.isNotEmpty
            ? doneCount / relatedTasks.length
            : (goal.isDone ? 1.0 : 0.0);

        return MochiCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: goal.isDone,
                      activeColor: palette.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      onChanged: (val) =>
                          store.toggleGoal(goal.id, val ?? false),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: goal.isDone ? palette.muted : palette.ink,
                              decoration: goal.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _MetaChip(
                                icon: Icons.event_rounded,
                                label:
                                    'Hạn ${goal.targetDate.day}/${goal.targetDate.month}/${goal.targetDate.year}',
                                tone: MochiChipTone.neutral,
                              ),
                              _MetaChip(
                                label: goal.subject,
                                tone: MochiChipTone.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    MochiIconButton(
                      tooltip: 'Xóa mục tiêu ${goal.title}',
                      icon: Icons.delete_outline_rounded,
                      color: palette.danger,
                      filled: false,
                      size: 40,
                      onPressed: () => _confirmDeleteGoal(store, goal),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                MochiProgressBar(
                  value: progressPct,
                  height: 9,
                  showValue: false,
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$doneCount / ${relatedTasks.length} nhiệm vụ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MochiPalette.of(context).muted,
                      ),
                    ),
                    MochiButton(
                      label: 'AI chia nhỏ việc',
                      icon: Icons.auto_awesome_rounded,
                      size: MochiButtonSize.small,
                      variant: MochiButtonVariant.secondary,
                      onPressed: goal.isDone
                          ? null
                          : () => _showAIPlannerDialog(store, goal),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ADD TASK DIALOG ---

  Future<void> _showAddTaskDialog(MochiStore store) async {
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '25');
    String selectedSubject = 'Toán';
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void submit() {
            final title = titleCtrl.text.trim();
            final duration = int.tryParse(durationCtrl.text.trim());
            if (title.isEmpty) {
              setDialogState(() => errorText = 'Hãy nhập tên nhiệm vụ.');
              return;
            }
            if (duration == null || duration < 1 || duration > 180) {
              setDialogState(
                () => errorText = 'Thời lượng cần từ 1 đến 180 phút.',
              );
              return;
            }
            store.addTask(
              title: title,
              subject: selectedSubject,
              duration: duration,
            );
            Navigator.pop(ctx);
          }

          return _plannerFormDialog(
            ctx,
            icon: Icons.add_task_rounded,
            title: 'Thêm nhiệm vụ',
            subtitle: 'Ghi lại việc cần làm và thời lượng dự kiến.',
            submitLabel: 'Lưu nhiệm vụ',
            onCancel: () => Navigator.pop(ctx),
            onSubmit: submit,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Nhiệm vụ cụ thể'),
                MochiTextField(
                  controller: titleCtrl,
                  textInputAction: TextInputAction.next,
                  hint: 'Ví dụ: Làm bài tập 1 đến 5 trang 42',
                ),
                const SizedBox(height: MochiSpacing.md),
                const _FieldLabel('Môn học'),
                DropdownButtonFormField<String>(
                  initialValue: selectedSubject,
                  items: _kSubjects
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedSubject = val);
                    }
                  },
                ),
                const SizedBox(height: MochiSpacing.md),
                const _FieldLabel('Thời lượng (phút)'),
                MochiTextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  hint: '25',
                ),
                if (errorText != null) ...[
                  const SizedBox(height: MochiSpacing.sm),
                  Text(
                    errorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MochiPalette.of(context).danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    titleCtrl.dispose();
    durationCtrl.dispose();
  }

  // --- ADD GOAL DIALOG ---

  Future<void> _showAddGoalDialog(MochiStore store) async {
    final titleCtrl = TextEditingController();
    DateTime targetDate = DateTime.now().add(Duration(days: 30));
    String selectedSubject = _kSubjects.first;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void submit() {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) {
              setDialogState(() => errorText = 'Hãy nhập mục tiêu học tập.');
              return;
            }
            store.addGoal(title, targetDate, subject: selectedSubject);
            Navigator.pop(ctx);
          }

          return _plannerFormDialog(
            ctx,
            icon: Icons.flag_outlined,
            title: 'Thêm mục tiêu',
            subtitle: 'Chọn một đích đến rõ ràng để Mochi giúp bạn chia nhỏ.',
            submitLabel: 'Lưu mục tiêu',
            onCancel: () => Navigator.pop(ctx),
            onSubmit: submit,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Mục tiêu học tập'),
                MochiTextField(
                  controller: titleCtrl,
                  maxLines: 2,
                  minLines: 1,
                  hint: 'Ví dụ: Ôn tập đạt điểm A kỳ thi giữa kỳ',
                ),
                const SizedBox(height: MochiSpacing.md),
                const _FieldLabel('Môn trọng tâm'),
                DropdownButtonFormField<String>(
                  initialValue: selectedSubject,
                  items: _kSubjects
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedSubject = val);
                    }
                  },
                ),
                const SizedBox(height: MochiSpacing.md),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: MochiSpacing.sm,
                  runSpacing: MochiSpacing.xs,
                  children: [
                    Text(
                      'Hạn: ${targetDate.day}/${targetDate.month}/${targetDate.year}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MochiPalette.of(context).ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    MochiButton(
                      label: 'Chọn ngày',
                      icon: Icons.calendar_month_outlined,
                      size: MochiButtonSize.small,
                      variant: MochiButtonVariant.secondary,
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: targetDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => targetDate = picked);
                        }
                      },
                    ),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: MochiSpacing.sm),
                  Text(
                    errorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MochiPalette.of(context).danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    titleCtrl.dispose();
  }

  // --- AI PLANNER ---

  Future<void> _showAIPlannerDialog(MochiStore store, GoalModel goal) async {
    // Lấy lịch sinh hoạt người học đã cấu hình trong mục Tôi.
    final routine = store.dailyRoutine;
    final freeStart = routine.eveningFreeStart;
    final freeEnd = routine.eveningFreeEnd;
    final dailyMinutes = routine.preferredDailyMinutes;
    final totalDays = goal.targetDate
        .difference(DateTime.now())
        .inDays
        .clamp(1, 365)
        .toInt();

    _showPlanningLoading();
    List<Map<String, dynamic>> drafts;
    try {
      drafts = await store.aiService.breakDownGoalIntoTasks(
        goalTitle: goal.title,
        subject: goal.subject,
        totalDays: totalDays,
        dailyMinutes: dailyMinutes,
        freeTimeStart: freeStart,
        freeTimeEnd: freeEnd,
        routine: routine,
        existingTasks: store.tasks,
      );
    } catch (error) {
      if (!mounted) return;
      _closePlanningLoading();
      _showPlannerError(error);
      return;
    }

    if (!mounted) return;
    _closePlanningLoading();
    if (drafts.isEmpty) {
      _showPlannerError(StateError('Không có nhiệm vụ nào được đề xuất.'));
      return;
    }
    await _showPlanPreview(store, goal, drafts);
  }

  void _showPlanningLoading() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: MochiCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: MochiPalette.of(context).action,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Đang sắp xếp các mốc giờ học…',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _closePlanningLoading() {
    // The loading dialog is pushed with showDialog, so it lives on the root
    // navigator; popping it here never closes the planner itself.
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showPlannerError(Object error) {
    final raw = error.toString();
    final message = raw.contains('Không đủ giờ rảnh')
        ? 'Không đủ giờ rảnh trước hạn. Hãy nới lịch sinh hoạt hoặc đổi hạn mục tiêu.'
        : raw.contains('vượt ngân sách')
        ? 'Một nhiệm vụ vượt ngân sách phút mỗi ngày. Hãy tăng thời lượng học mỗi ngày.'
        : 'Chưa tạo được kế hoạch. Kiểm tra Lịch sinh hoạt và kết nối mạng rồi thử lại.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Mở lịch sinh hoạt',
          onPressed: _openRoutineSettings,
        ),
      ),
    );
  }

  void _openRoutineSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RoutineScreen()));
  }

  Future<void> _showPlanPreview(
    MochiStore store,
    GoalModel goal,
    List<Map<String, dynamic>> drafts,
  ) async {
    final offline = drafts.every((d) => d['source'] == 'offline_template');
    final dates =
        drafts
            .map((d) => DateTime.tryParse(d['scheduledDate']?.toString() ?? ''))
            .whereType<DateTime>()
            .toList()
          ..sort();
    final dailyMinutes = store.dailyRoutine.preferredDailyMinutes;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MochiPalette.of(context).card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _PlanPreviewSheet(
        goal: goal,
        drafts: drafts,
        offline: offline,
        firstDay: dates.isEmpty ? null : dates.first,
        lastDay: dates.isEmpty ? null : dates.last,
        dailyMinutes: dailyMinutes,
        onApply: () => Navigator.pop(sheetContext, true),
      ),
    );

    if (applied == true && mounted) {
      await _applyPlan(store, goal, drafts, offline: offline);
    }
  }

  Future<void> _applyPlan(
    MochiStore store,
    GoalModel goal,
    List<Map<String, dynamic>> drafts, {
    required bool offline,
  }) async {
    final now = DateTime.now();
    final fallbackDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fallbackTime = store.dailyRoutine.eveningFreeStart;

    for (final draft in drafts) {
      store.addTask(
        title: draft['title']?.toString() ?? 'Nhiệm vụ học tập',
        goalId: goal.id,
        subject: draft['subject']?.toString() ?? goal.subject,
        duration: _asInt(draft['durationMinutes'], 25),
        priority: _asInt(draft['priority'], 0),
        scheduledDate: draft['scheduledDate']?.toString() ?? fallbackDate,
        scheduledTime: draft['scheduledTime']?.toString() ?? fallbackTime,
      );
    }

    final count = drafts.length;
    final suffix = offline ? ' (kế hoạch mẫu ngoại tuyến)' : '';
    final messenger = ScaffoldMessenger.of(context);

    if (!NotificationService.supported) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu $count nhiệm vụ$suffix. Bản Web không có nhắc học trên thiết bị.',
          ),
        ),
      );
      return;
    }

    final notifications = NotificationService();
    try {
      final allowed = await notifications.notificationsEnabled();
      if (!mounted) return;
      if (!allowed) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Đã lưu $count nhiệm vụ$suffix nhưng chưa đặt được nhắc học vì quyền thông báo đang tắt.',
            ),
            duration: Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Mở cài đặt',
              onPressed: notifications.openSystemSettings,
            ),
          ),
        );
        return;
      }

      final reminders = SmartReminderService();
      await reminders.refresh();
      if (!mounted) return;
      final scheduled = reminders.scheduled.length;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            scheduled > 0
                ? 'Đã lưu $count nhiệm vụ$suffix và hẹn $scheduled lời nhắc gần nhất.'
                : 'Đã lưu $count nhiệm vụ$suffix. Lịch nhắc sẽ cập nhật khi mở ứng dụng.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu $count nhiệm vụ$suffix. Chưa kiểm tra được quyền thông báo.',
          ),
          action: SnackBarAction(
            label: 'Mở cài đặt',
            onPressed: notifications.openSystemSettings,
          ),
        ),
      );
    }
  }

  // --- DELETE CONFIRMATIONS ---

  Future<void> _confirmDeleteTask(MochiStore store, TaskModel task) async {
    final confirmed = await _showDeleteDialog(
      title: 'Xóa nhiệm vụ?',
      message:
          '"${task.title}" sẽ bị xóa khỏi kế hoạch học tập. Thao tác này không thể hoàn tác.',
    );
    if (confirmed == true) store.deleteTask(task.id);
  }

  Future<void> _confirmDeleteGoal(MochiStore store, GoalModel goal) async {
    final childCount = store.tasks.where((t) => t.goalId == goal.id).length;
    final message = childCount > 0
        ? '"${goal.title}" và $childCount nhiệm vụ con sẽ bị xóa khỏi kế hoạch. Thao tác này không thể hoàn tác.'
        : '"${goal.title}" sẽ bị xóa khỏi kế hoạch. Thao tác này không thể hoàn tác.';
    final confirmed = await _showDeleteDialog(
      title: 'Xóa mục tiêu?',
      message: message,
    );
    if (confirmed == true) store.deleteGoal(goal.id);
  }

  Future<bool?> _showDeleteDialog({
    required String title,
    required String message,
  }) async {
    final confirmed = await MochiDialog.show(
      context,
      title: title,
      message: message,
      confirmLabel: 'Xóa',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    return confirmed;
  }

  static int _asInt(Object? value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
}

// --- SHARED PLAN WIDGETS ---

class _PlanPreviewSheet extends StatelessWidget {
  const _PlanPreviewSheet({
    required this.goal,
    required this.drafts,
    required this.offline,
    required this.firstDay,
    required this.lastDay,
    required this.dailyMinutes,
    required this.onApply,
  });

  final GoalModel goal;
  final List<Map<String, dynamic>> drafts;
  final bool offline;
  final DateTime? firstDay;
  final DateTime? lastDay;
  final int dailyMinutes;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 640) / 2
                : 20.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MochiPalette.of(context).cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  child: _header(context),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 12),
                    children: [
                      if (offline) ...[
                        const _OfflinePlanNotice(),
                        SizedBox(height: 12),
                      ],
                      _ReviewNotice(dailyMinutes: dailyMinutes),
                      SizedBox(height: 12),
                      ...drafts.map((draft) => _draftTile(context, draft)),
                    ],
                  ),
                ),
                _actions(context, horizontal),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final range = firstDay == null
        ? 'Chưa có ngày cụ thể'
        : '${_formatDay(firstDay)} – ${_formatDay(lastDay)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome, color: MochiPalette.of(context).action),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kế hoạch đề xuất',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: MochiPalette.of(context).ink,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '"${goal.title}" · ${drafts.length} nhiệm vụ · $range',
                style: TextStyle(
                  fontSize: 12.5,
                  color: MochiPalette.of(context).muted,
                ),
              ),
            ],
          ),
        ),
        MochiIconButton(
          tooltip: 'Đóng',
          filled: false,
          icon: Icons.close_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _draftTile(BuildContext context, Map<String, dynamic> draft) {
    final time = draft['scheduledTime']?.toString() ?? '';
    final date = draft['scheduledDate']?.toString() ?? '';
    final duration = draft['durationMinutes']?.toString() ?? '25';
    final subject = draft['subject']?.toString() ?? goal.subject;

    return MochiCard(
      margin: const EdgeInsets.only(bottom: MochiSpacing.sm),
      padding: const EdgeInsets.all(MochiSpacing.sm),
      radius: 18,
      color: MochiPalette.of(context).cardSoft,
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (time.isNotEmpty)
            _MetaChip(
              icon: Icons.schedule_rounded,
              label: time,
              tone: MochiChipTone.accent,
            ),
          const SizedBox(width: MochiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft['title']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: MochiPalette.of(context).ink,
                  ),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaChip(
                      label: date.isEmpty
                          ? 'Chưa xếp ngày'
                          : _formatDay(DateTime.tryParse(date)),
                      tone: MochiChipTone.neutral,
                    ),
                    _MetaChip(
                      label: '$duration phút',
                      tone: MochiChipTone.neutral,
                    ),
                    _MetaChip(label: subject, tone: MochiChipTone.accent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, double horizontal) {
    final apply = MochiButton(
      onPressed: onApply,
      label: offline ? 'Áp dụng kế hoạch mẫu' : 'Áp dụng & Nhắc nhở',
      icon: Icons.check_rounded,
      expand: true,
    );
    final cancel = MochiButton(
      label: 'Bỏ qua',
      variant: MochiButtonVariant.secondary,
      onPressed: () => Navigator.pop(context),
      expand: true,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [apply, SizedBox(height: 8), cancel],
            );
          }
          return Row(
            children: [
              Expanded(child: cancel),
              SizedBox(width: 12),
              Expanded(flex: 2, child: apply),
            ],
          );
        },
      ),
    );
  }

  static String _formatDay(DateTime? day) =>
      day == null ? '—' : '${day.day}/${day.month}';
}

class _OfflinePlanNotice extends StatelessWidget {
  const _OfflinePlanNotice();

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return MochiCard(
      padding: const EdgeInsets.all(MochiSpacing.sm),
      radius: 18,
      color: palette.warningSoft,
      borderColor: palette.warningSoft,
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: palette.warning),
          const SizedBox(width: MochiSpacing.sm),
          Expanded(
            child: Text(
              'Kế hoạch mẫu ngoại tuyến. AI chưa phản hồi, nên nội dung do Mochi tạo theo quy tắc. Bạn kiểm tra lại trước khi áp dụng.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: palette.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({required this.dailyMinutes});

  final int dailyMinutes;

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return MochiCard(
      padding: const EdgeInsets.all(MochiSpacing.sm),
      radius: 18,
      color: palette.cardSoft,
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: palette.action),
          const SizedBox(width: MochiSpacing.xs),
          Expanded(
            child: Text(
              'Đây là đề xuất chưa được lưu. Giờ học đã tránh các nhiệm vụ hiện có và giới hạn $dailyMinutes phút/ngày; hãy kiểm tra lại trước khi áp dụng.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(height: 1.4, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SHARED SMALL WIDGETS ---

String _formatShortDate(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  return parsed == null ? (value ?? '') : '${parsed.day}/${parsed.month}';
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.tone = MochiChipTone.neutral,
    this.icon,
  });

  final String label;
  final MochiChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      MochiChip(label: label, icon: icon, tone: tone, compact: true);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MochiSpacing.xs),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: MochiPalette.of(context).muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _PlannerEmptyState extends StatelessWidget {
  const _PlannerEmptyState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.bottomInset,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          MochiSpacing.lg,
          MochiSpacing.lg,
          MochiSpacing.lg,
          bottomInset + MochiSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: MochiCard(
            padding: const EdgeInsets.all(MochiSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: palette.softAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
                const SizedBox(height: MochiSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: MochiSpacing.xs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
