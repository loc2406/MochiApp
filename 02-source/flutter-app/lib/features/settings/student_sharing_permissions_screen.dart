import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/student_share_sections.dart';
import '../../design/mochi_design.dart';
import 'student_share_options.dart';

/// Lets the student choose which pieces of their data one viewer email can see.
class StudentSharingPermissionsScreen extends StatefulWidget {
  final String viewerId;
  final String email;
  final String role;
  final List<String> initialSections;
  final DateTime? lastViewedAt;

  const StudentSharingPermissionsScreen({
    super.key,
    required this.viewerId,
    required this.email,
    required this.role,
    required this.initialSections,
    this.lastViewedAt,
  });

  @override
  State<StudentSharingPermissionsScreen> createState() =>
      _StudentSharingPermissionsScreenState();
}

class _StudentSharingPermissionsScreenState
    extends State<StudentSharingPermissionsScreen> {
  late final Set<String> _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = StudentShareSections.parse(widget.initialSections);
  }

  bool get _allSelected => _selected.length == StudentShareSections.all.length;

  void _toggle(String key, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
      _error = null;
    });
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(StudentShareSections.all);
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<MochiStore>().cloudService.updateStudentViewerSections(
        viewerId: widget.viewerId,
        sections: StudentShareSections.all
            .where(_selected.contains)
            .toList(growable: false),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu quyền xem thông tin.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Chưa lưu được thay đổi. Kiểm tra kết nối và thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return MochiScaffold(
      maxWidth: 720,
      appBar: MochiAppBar.detail(
        title: 'Quyền xem thông tin',
        subtitle: widget.email,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth < 420
              ? MochiSpacing.md
              : MochiSpacing.xl;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    MochiSpacing.sm,
                    horizontal,
                    MochiSpacing.xl,
                  ),
                  children: [
                    _ViewerSummaryCard(
                      email: widget.email,
                      role: widget.role,
                      lastViewedAt: widget.lastViewedAt,
                      selectedCount: _selected.length,
                    ),
                    const SizedBox(height: MochiSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thông tin được phép xem',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: palette.ink,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: _saving ? null : _toggleAll,
                          child: Text(
                            _allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MochiSpacing.xs),
                    MochiSection(
                      children: [
                        for (final option in studentShareOptions)
                          _ShareOptionRow(
                            option: option,
                            selected: _selected.contains(option.key),
                            enabled: !_saving,
                            onChanged: (value) => _toggle(option.key, value),
                          ),
                      ],
                    ),
                    if (_selected.isEmpty) ...[
                      const SizedBox(height: MochiSpacing.md),
                      const MochiNoticeBanner(
                        message: 'Người xem vẫn vào được bằng mã mời nhưng sẽ chỉ thấy thông báo là học sinh chưa chia sẻ thông tin nào.',
                        severity: MochiNoticeSeverity.warning,
                        compact: true,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: MochiSpacing.md),
                      MochiNoticeBanner(
                        message: _error!,
                        severity: MochiNoticeSeverity.error,
                        compact: true,
                      ),
                    ],
                    const SizedBox(height: MochiSpacing.md),
                    Text(
                      'Thay đổi áp dụng cho mọi mã mời đang hoạt động của email này. '
                      'Nếu học sinh tạo mã mới, các mục đã chọn vẫn được giữ nguyên.',
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  MochiSpacing.sm,
                  horizontal,
                  MochiSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: palette.navBar,
                  border: Border(top: BorderSide(color: palette.cardBorder)),
                ),
                child: SafeArea(
                  top: false,
                  child: MochiButton(
                    label: 'Lưu thay đổi',
                    icon: Icons.save_rounded,
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                    expand: true,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ViewerSummaryCard extends StatelessWidget {
  final String email;
  final String role;
  final DateTime? lastViewedAt;
  final int selectedCount;

  const _ViewerSummaryCard({
    required this.email,
    required this.role,
    required this.lastViewedAt,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final isTeacher = role == 'teacher';
    return MochiCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: palette.softAccent,
            child: Icon(
              isTeacher ? Icons.school_outlined : Icons.family_restroom_rounded,
              color: palette.action,
            ),
          ),
          const SizedBox(width: MochiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isTeacher ? 'Giáo viên' : 'Phụ huynh',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
                if (lastViewedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Xem gần nhất: ${DateFormat('dd/MM/yyyy HH:mm').format(lastViewedAt!)}',
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: MochiSpacing.xs),
          MochiChip(
            label: '$selectedCount/${StudentShareSections.all.length}',
            tone: selectedCount == 0
                ? MochiChipTone.warning
                : MochiChipTone.accent,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _ShareOptionRow extends StatelessWidget {
  final StudentShareOption option;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ShareOptionRow({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return InkWell(
      onTap: enabled ? () => onChanged(!selected) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MochiSpacing.md,
          vertical: MochiSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? palette.softAccent : palette.cardSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                option.icon,
                size: MochiIconSize.md,
                color: selected ? palette.action : palette.muted,
              ),
            ),
            const SizedBox(width: MochiSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MochiSpacing.xs),
            Checkbox.adaptive(
              value: selected,
              onChanged: enabled ? (value) => onChanged(value ?? false) : null,
              activeColor: palette.action,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
