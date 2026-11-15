import '../../../design/mochi_design.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/database/mochi_store.dart';
import '../../../core/models/mochi_models.dart';

class ScheduleChangeCard extends StatefulWidget {
  final ChatMessageModel message;
  const ScheduleChangeCard({super.key, required this.message});
  @override
  State<ScheduleChangeCard> createState() => _ScheduleChangeCardState();
}

class _ScheduleChangeCardState extends State<ScheduleChangeCard> {
  bool _saving = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final message =
        store.tutorMessages
            .where((m) => m.id == widget.message.id)
            .firstOrNull ??
        widget.message;
    final action = message.scheduleActionData ?? {};
    final applied = action['status'] == 'applied';
    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MochiPalette.of(context).warningSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MochiPalette.of(context).cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Đề xuất dời lịch',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(action['taskTitle']?.toString() ?? 'Nhiệm vụ chưa xác định'),
          SizedBox(height: 8),
          Text(
            'Trước: ${action['oldDate'] ?? 'Chưa xếp ngày'} · ${action['oldTime'] ?? 'Chưa xếp giờ'}',
          ),
          Text(
            'Sau: ${action['date'] ?? 'Chưa rõ ngày'} · ${action['newTime'] ?? 'Chưa rõ giờ'}',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          if (applied)
            Text(
              store.isCloudSynced
                  ? 'Đã cập nhật và đồng bộ tài khoản.'
                  : 'Đã đổi trên máy; đang chờ đồng bộ tài khoản.',
            )
          else
            MochiPrimaryButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() {
                        _saving = true;
                        _error = null;
                      });
                      try {
                        await store.confirmTutorScheduleChange(message.id);
                      } catch (e) {
                        if (mounted)
                          setState(
                            () => _error = e
                                .toString()
                                .replaceFirst('Bad state: ', '')
                                .replaceFirst('Invalid argument(s): ', ''),
                          );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(
                _saving ? 'Đang kiểm tra và lưu…' : 'Xác nhận dời lịch',
              ),
            ),
          if (_error != null) ...[
            SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: MochiPalette.of(context).danger),
            ),
          ],
        ],
      ),
    );
  }
}
