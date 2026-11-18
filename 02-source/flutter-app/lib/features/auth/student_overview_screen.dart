import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/student_share_sections.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../design/mochi_design.dart';

class StudentOverviewScreen extends StatefulWidget {
  const StudentOverviewScreen({super.key});

  @override
  State<StudentOverviewScreen> createState() => _StudentOverviewScreenState();
}

class _StudentOverviewScreenState extends State<StudentOverviewScreen> {
  final CloudSyncService _cloud = CloudSyncService();
  Map<String, dynamic>? _overview;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _cloud.fetchStudentOverview();
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _error = 'Phiên xem không còn hiệu lực. Hãy nhập lại mã mời.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _overview = result;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      await _cloud.clearStudentViewerSession();
      if (!mounted) return;
      setState(() {
        _error = 'Quyền xem đã bị thu hồi hoặc chưa thể tải dữ liệu.';
        _loading = false;
      });
    }
  }

  Future<void> _exitViewerMode() async {
    await _cloud.clearStudentViewerSession();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final data = _overview;
    final sections = StudentShareSections.parse(data?['sharedSections']);
    final goals = sections.contains(StudentShareSections.goals)
        ? _mapList(data?['goals'])
        : <Map<String, dynamic>>[];
    final courses = sections.contains(StudentShareSections.courses)
        ? _mapList(data?['courses'])
        : <Map<String, dynamic>>[];
    final completedGoals = goals.where((goal) => goal['isDone'] == true).length;

    return MochiScaffold(
      appBar: MochiAppBar.detail(
        title: 'Tổng quan học tập',
        subtitle: data == null
            ? 'Kết nối bằng mã mời'
            : 'Thông tin được học sinh chia sẻ',
        actions: [
          IconButton(
            tooltip: 'Thoát chế độ xem',
            onPressed: _exitViewerMode,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(context, palette)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  MochiSpacing.md,
                  MochiSpacing.sm,
                  MochiSpacing.md,
                  MochiSpacing.xxl,
                ),
                children: data == null
                    ? const []
                    : sections.isEmpty
                    ? [_buildNothingShared(context, palette)]
                    : [
                        if (sections.contains(
                          StudentShareSections.profile,
                        )) ...[
                          _buildStudentHeader(context, palette, data),
                          const SizedBox(height: MochiSpacing.md),
                        ],
                        if (_hasMetric(sections)) ...[
                          _buildMetrics(context, sections, data),
                          const SizedBox(height: MochiSpacing.md),
                        ],
                        if (sections.contains(StudentShareSections.goals)) ...[
                          _buildGoals(context, palette, goals),
                          const SizedBox(height: MochiSpacing.md),
                        ],
                        if (sections.contains(
                          StudentShareSections.courses,
                        )) ...[
                          _buildCourses(context, palette, courses),
                          const SizedBox(height: MochiSpacing.md),
                        ],
                        if (sections.contains(
                          StudentShareSections.progress,
                        )) ...[
                          _buildProgress(context, palette, data),
                          const SizedBox(height: MochiSpacing.md),
                        ],
                        if (sections.contains(
                          StudentShareSections.recentStudy,
                        )) ...[
                          _buildRecentStudy(context, palette, data),
                          const SizedBox(height: MochiSpacing.md),
                        ],
                        if (sections.contains(StudentShareSections.goals))
                          _buildGoalSummary(
                            context,
                            palette,
                            completedGoals,
                            goals.length,
                          ),
                      ],
              ),
            ),
    );
  }

  bool _hasMetric(Set<String> sections) =>
      sections.contains(StudentShareSections.xp) ||
      sections.contains(StudentShareSections.streak) ||
      sections.contains(StudentShareSections.studyMinutes);

  Widget _buildStudentHeader(
    BuildContext context,
    MochiPalette palette,
    Map<String, dynamic> data,
  ) {
    final grade = '${data['grade'] ?? ''}'.trim();
    return MochiCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: palette.accent.withValues(alpha: 0.16),
            child: Icon(Icons.school_rounded, color: palette.action),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['studentName'] ?? 'Học sinh'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Lớp/khối: ${grade.isEmpty ? 'Chưa cập nhật' : grade}',
                  style: TextStyle(color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(
    BuildContext context,
    Set<String> sections,
    Map<String, dynamic> data,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 380 ? 2 : 3;
        final tileWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (sections.contains(StudentShareSections.xp))
              _metric(
                context,
                tileWidth,
                'XP',
                '${data['xp'] ?? 0}',
                Icons.bolt_rounded,
              ),
            if (sections.contains(StudentShareSections.streak))
              _metric(
                context,
                tileWidth,
                'Chuỗi ngày',
                '${data['currentStreak'] ?? 0}',
                Icons.local_fire_department_rounded,
              ),
            if (sections.contains(StudentShareSections.studyMinutes))
              _metric(
                context,
                tileWidth,
                'Phút học',
                '${data['totalStudyMinutes'] ?? 0}',
                Icons.schedule_rounded,
              ),
          ],
        );
      },
    );
  }

  Widget _buildGoals(
    BuildContext context,
    MochiPalette palette,
    List<Map<String, dynamic>> goals,
  ) {
    return MochiSection(
      title: 'Mục tiêu học tập',
      children: goals.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Chưa có mục tiêu được chia sẻ.',
                  style: TextStyle(color: palette.muted),
                ),
              ),
            ]
          : goals.map((goal) {
              final isDone = goal['isDone'] == true;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.flag_outlined,
                  color: isDone ? palette.action : palette.accent,
                ),
                title: Text(
                  '${goal['title'] ?? 'Mục tiêu'}',
                  style: TextStyle(color: palette.ink),
                ),
                subtitle: Text(
                  '${goal['subject'] ?? 'Chung'}',
                  style: TextStyle(color: palette.muted),
                ),
                trailing: isDone
                    ? Text(
                        'Hoàn thành',
                        style: TextStyle(color: palette.action, fontSize: 11),
                      )
                    : null,
              );
            }).toList(),
    );
  }

  Widget _buildCourses(
    BuildContext context,
    MochiPalette palette,
    List<Map<String, dynamic>> courses,
  ) {
    return MochiSection(
      title: 'Môn học',
      children: courses.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Chưa có môn học được chia sẻ.',
                  style: TextStyle(color: palette.muted),
                ),
              ),
            ]
          : courses.map((course) {
              final topics = course['topics'];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: Icon(Icons.menu_book_rounded, color: palette.action),
                title: Text(
                  '${course['subject'] ?? 'Môn học'}',
                  style: TextStyle(color: palette.ink),
                ),
                subtitle: topics is List
                    ? Text(
                        '${topics.length} chủ đề',
                        style: TextStyle(color: palette.muted),
                      )
                    : null,
              );
            }).toList(),
    );
  }

  Widget _buildProgress(
    BuildContext context,
    MochiPalette palette,
    Map<String, dynamic> data,
  ) {
    final progress = _mapList(data['progress']);
    final topics = <String, Map<String, String>>{};
    for (final course in _mapList(data['courses'])) {
      final subject = '${course['subject'] ?? 'Môn học'}';
      for (final topic in _mapList(course['topics'])) {
        topics['${topic['id'] ?? ''}'] = {
          'title': '${topic['title'] ?? 'Chủ đề'}',
          'subject': subject,
        };
      }
    }

    return MochiSection(
      title: 'Tiến độ chủ đề',
      children: progress.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Chưa có tiến độ chủ đề được chia sẻ.',
                  style: TextStyle(color: palette.muted),
                ),
              ),
            ]
          : progress.map((entry) {
              final readiness = '${entry['readiness'] ?? 'unknown'}';
              final topic = topics['${entry['topicId'] ?? ''}'];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: Icon(
                  _readinessIcon(readiness),
                  color: _readinessColor(palette, readiness),
                ),
                title: Text(
                  '${entry['topicTitle'] ?? topic?['title'] ?? 'Chủ đề'}',
                  style: TextStyle(color: palette.ink),
                ),
                subtitle: Text(
                  '${entry['subject'] ?? topic?['subject'] ?? 'Chung'}',
                  style: TextStyle(color: palette.muted),
                ),
                trailing: MochiChip(
                  label: _readinessLabel(readiness),
                  tone: _readinessTone(readiness),
                  compact: true,
                ),
              );
            }).toList(),
    );
  }

  Widget _buildRecentStudy(
    BuildContext context,
    MochiPalette palette,
    Map<String, dynamic> data,
  ) {
    final recent = _mapList(data['recentStudy']);
    return MochiSection(
      title: 'Hoạt động gần đây',
      children: recent.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Chưa có hoạt động học nào được chia sẻ.',
                  style: TextStyle(color: palette.muted),
                ),
              ),
            ]
          : recent.map((entry) {
              final date = DateTime.tryParse(entry['date']?.toString() ?? '')
                  ?.toLocal();
              final minutes = (entry['durationMinutes'] as num?)?.toInt() ?? 0;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: Icon(Icons.history_rounded, color: palette.action),
                title: Text(
                  date == null
                      ? 'Buổi học'
                      : DateFormat('dd/MM/yyyy • HH:mm').format(date),
                  style: TextStyle(color: palette.ink),
                ),
                subtitle: Text(
                  '$minutes phút học',
                  style: TextStyle(color: palette.muted),
                ),
              );
            }).toList(),
    );
  }

  Widget _buildGoalSummary(
    BuildContext context,
    MochiPalette palette,
    int completedGoals,
    int totalGoals,
  ) {
    return MochiCard(
      child: Row(
        children: [
          Icon(Icons.track_changes_rounded, color: palette.action),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đã hoàn thành $completedGoals/$totalGoals mục tiêu đang chia sẻ.',
              style: TextStyle(color: palette.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNothingShared(BuildContext context, MochiPalette palette) {
    return MochiCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 42, color: palette.muted),
          const SizedBox(height: MochiSpacing.sm),
          Text(
            'Học sinh chưa chia sẻ thông tin nào',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: palette.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Hãy liên hệ học sinh để được cấp quyền xem một số mục thông tin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
          const SizedBox(height: MochiSpacing.md),
          MochiButton(
            label: 'Tải lại',
            icon: Icons.refresh_rounded,
            onPressed: () => _load(),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, MochiPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MochiCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 38, color: palette.muted),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.ink),
              ),
              const SizedBox(height: 12),
              MochiButton(
                label: 'Quay lại',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _readinessLabel(String readiness) => switch (readiness) {
    'confident' => 'Đã nắm vững',
    'needsReview' => 'Cần ôn lại',
    'notStudied' => 'Chưa học',
    _ => 'Chưa cập nhật',
  };

  MochiChipTone _readinessTone(String readiness) => switch (readiness) {
    'confident' => MochiChipTone.success,
    'needsReview' => MochiChipTone.warning,
    _ => MochiChipTone.neutral,
  };

  Color _readinessColor(MochiPalette palette, String readiness) =>
      switch (readiness) {
        'confident' => palette.success,
        'needsReview' => palette.warning,
        _ => palette.muted,
      };

  IconData _readinessIcon(String readiness) => switch (readiness) {
    'confident' => Icons.verified_rounded,
    'needsReview' => Icons.autorenew_rounded,
    'notStudied' => Icons.circle_outlined,
    _ => Icons.help_outline_rounded,
  };

  Widget _metric(
    BuildContext context,
    double width,
    String label,
    String value,
    IconData icon,
  ) {
    final palette = MochiPalette.of(context);
    return SizedBox(
      width: width,
      child: MochiCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: palette.action),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: palette.ink, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
