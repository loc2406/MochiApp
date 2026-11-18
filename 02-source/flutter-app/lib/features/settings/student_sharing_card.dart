import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/student_share_sections.dart';
import '../../design/mochi_design.dart';
import 'student_sharing_permissions_screen.dart';

class StudentSharingCard extends StatefulWidget {
  const StudentSharingCard({super.key});

  @override
  State<StudentSharingCard> createState() => _StudentSharingCardState();
}

class _StudentSharingCardState extends State<StudentSharingCard> {
  final _email = TextEditingController();
  String _role = 'parent';
  bool _busy = false;
  String? _code;
  List<Map<String, dynamic>> _viewers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadViewers());
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String _newCode() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlNoPadding(bytes);
  }

  String base64UrlNoPadding(List<int> bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final out = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final a = bytes[i],
          b = i + 1 < bytes.length ? bytes[i + 1] : 0,
          c = i + 2 < bytes.length ? bytes[i + 2] : 0;
      final n = (a << 16) | (b << 8) | c;
      out.write(chars[(n >> 18) & 63]);
      out.write(chars[(n >> 12) & 63]);
      if (i + 1 < bytes.length) out.write(chars[(n >> 6) & 63]);
      if (i + 2 < bytes.length) out.write(chars[n & 63]);
    }
    return out.toString();
  }

  Future<void> _create() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Nhập email người xem hợp lệ.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _code = null;
    });
    try {
      final code = await context
          .read<MochiStore>()
          .cloudService
          .createStudentInvite(email: email, role: _role, code: _newCode());
      if (mounted) setState(() => _code = code);
      await _loadViewers();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không tạo được mã. Hãy đăng nhập tài khoản học tập và thử lại.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _loadViewers() async {
    try {
      final rows = await context
          .read<MochiStore>()
          .cloudService
          .listStudentViewers();
      if (mounted) setState(() => _viewers = rows);
    } catch (_) {}
  }

  Future<void> _revoke(String id) async {
    try {
      await context.read<MochiStore>().cloudService.revokeStudentViewer(id);
      await _loadViewers();
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa thu hồi được quyền xem.');
    }
  }

  Future<void> _openPermissions(Map<String, dynamic> viewer) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StudentSharingPermissionsScreen(
          viewerId: viewer['id'].toString(),
          email: '${viewer['email']}',
          role: '${viewer['role']}',
          initialSections: StudentShareSections.parse(viewer['sections'])
              .toList(growable: false),
          lastViewedAt: DateTime.tryParse(
            viewer['lastViewedAt']?.toString() ?? '',
          )?.toLocal(),
        ),
      ),
    );
    if (changed == true) await _loadViewers();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final signedIn = context.watch<MochiStore>().cloudService.hasActiveUser;
    return MochiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.share_outlined, color: palette.action),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chia sẻ tiến độ học tập',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo mã một lần cho phụ huynh hoặc giáo viên. Mã có hiệu lực trong 5 phút; hết hạn thì tạo mã mới. Nhấn vào một người xem để chọn đúng những thông tin họ được xem, và bạn có thể thu hồi quyền bất cứ lúc nào.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 16),
          if (!signedIn)
            MochiNoticeBanner(
              message:
                  'Đăng nhập tài khoản học tập để tạo và quản lý quyền xem.',
              severity: MochiNoticeSeverity.info,
              compact: true,
            )
          else ...[
            MochiTextField(
              controller: _email,
              label: 'Email người xem',
              hint: 'phuhuynh@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            MochiDropdownField<String>(
              label: 'Vai trò',
              value: _role,
              items: const [
                DropdownMenuItem(value: 'parent', child: Text('Phụ huynh')),
                DropdownMenuItem(value: 'teacher', child: Text('Giáo viên')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'parent'),
            ),
            const SizedBox(height: 12),
            MochiButton(
              label: 'Tạo mã mời dùng một lần',
              icon: Icons.key_rounded,
              loading: _busy,
              onPressed: _busy ? null : _create,
              expand: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              MochiNoticeBanner(
                message: _error!,
                severity: MochiNoticeSeverity.error,
                compact: true,
              ),
            ],
            if (_code != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.cardSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Gửi mã này cùng email đã nhập trong vòng 5 phút. Mã chỉ hiển thị lần này và chỉ dùng được một lần.',
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _code!,
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _code!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sao chép mã mời')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Sao chép'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đang có quyền xem',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Làm mới danh sách',
                  onPressed: _loadViewers,
                  icon: Icon(Icons.refresh_rounded, color: palette.action),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_viewers.isEmpty)
              Text(
                'Chưa có người xem nào. Danh sách sẽ cập nhật sau khi mã được sử dụng.',
                style: TextStyle(color: palette.muted, fontSize: 12),
              )
            else
              ..._viewers.map((viewer) {
                final lastViewedAt = DateTime.tryParse(
                  viewer['lastViewedAt']?.toString() ?? '',
                )?.toLocal();
                final sections = StudentShareSections.parse(viewer['sections']);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _openPermissions(viewer),
                  leading: Icon(
                    viewer['role'] == 'teacher'
                        ? Icons.school_outlined
                        : Icons.family_restroom_rounded,
                    color: palette.action,
                  ),
                  title: Text('${viewer['email']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${viewer['role'] == 'teacher' ? 'Giáo viên' : 'Phụ huynh'}'
                        '• Được xem ${sections.length}/${StudentShareSections.all.length} mục',
                      ),
                      Text(
                        lastViewedAt == null
                            ? 'Chưa xem lần nào'
                            : 'Xem gần nhất: ${DateFormat('dd/MM/yyyy HH:mm').format(lastViewedAt)}',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'Thu hồi quyền',
                    icon: Icon(
                      Icons.person_remove_alt_1_rounded,
                      color: palette.danger,
                    ),
                    onPressed: () => _revoke(viewer['id'].toString()),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
