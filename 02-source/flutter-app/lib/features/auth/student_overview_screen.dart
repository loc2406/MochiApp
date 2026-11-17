import 'package:flutter/material.dart';

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
    final goals = _mapList(data?['goals']);
    final courses = _mapList(data?['courses']);
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
                padding: const EdgeInsets.fromLTRB(
                  MochiSpacing.md,
                  MochiSpacing.sm,
                  MochiSpacing.md,
                  MochiSpacing.xxl,
                ),
                children: [
                  MochiCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: palette.accent.withValues(
                            alpha: 0.16,
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            color: palette.action,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data?['studentName'] ?? 'Học sinh'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: palette.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              Text(
                                'Lớp/khối: ${data?['grade'] ?? 'Chưa cập nhật'}',
                                style: TextStyle(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MochiSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 380 ? 2 : 3;
                      final tileWidth =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _metric(context, tileWidth, 'XP', '${data?['xp'] ?? 0}', Icons.bolt_rounded),
                          _metric(context, tileWidth, 'Chuỗi ngày', '${data?['currentStreak'] ?? 0}', Icons.local_fire_department_rounded),
                          _metric(context, tileWidth, 'Phút học', '${data?['totalStudyMinutes'] ?? 0}', Icons.schedule_rounded),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: MochiSpacing.md),
                  MochiSection(
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              leading: Icon(
                                isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.flag_outlined,
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
                                      style: TextStyle(
                                        color: palette.action,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: MochiSpacing.md),
                  MochiSection(
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              leading: Icon(
                                Icons.menu_book_rounded,
                                color: palette.action,
                              ),
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
                  ),
                  const SizedBox(height: MochiSpacing.md),
                  MochiCard(
                    child: Row(
                      children: [
                        Icon(Icons.track_changes_rounded, color: palette.action),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Đã hoàn thành $completedGoals/${goals.length} mục tiêu đang chia sẻ.',
                            style: TextStyle(
                              color: palette.ink,
                              fontWeight: FontWeight.w600,
                            ),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w800,
              ),
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
