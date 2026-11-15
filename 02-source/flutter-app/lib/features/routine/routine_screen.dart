import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../core/services/study_schedule.dart';
import '../../design/mochi_design.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  static const List<String> _weekdays = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  Future<void> _editRoutine({
    required String title,
    required String key,
    required bool isDate,
  }) async {
    final store = context.read<MochiStore>();
    final routine = store.dailyRoutine;

    final freeController = TextEditingController(
      text: isDate
          ? (routine.dateFree[key]?.join(', ') ?? '')
          : (routine.weeklyFree[key]?.join(', ') ??
                '${routine.eveningFreeStart}-${routine.eveningFreeEnd}'),
    );

    final busyController = TextEditingController(
      text:
          (isDate ? routine.dateBusy[key] : routine.weeklyBusy[key])?.join(
            ', ',
          ) ??
          '',
    );

    String? error;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final palette = MochiPalette.of(dialogContext);

            return AlertDialog(
              backgroundColor: palette.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.softAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: palette.action,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thiết lập các khoảng thời gian phù hợp với lịch sinh hoạt của bạn.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildTimeInput(
                      palette: palette,
                      controller: freeController,
                      label: 'Thời gian có thể học',
                      hint: '09:00-10:00, 19:30-21:00',
                      icon: Icons.menu_book_rounded,
                    ),
                    const SizedBox(height: 14),

                    _buildTimeInput(
                      palette: palette,
                      controller: busyController,
                      label: 'Thời gian bận',
                      hint: '12:00-13:00, 18:00-19:00',
                      icon: Icons.event_busy_rounded,
                    ),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.softAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: palette.action,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nhập nhiều khung giờ, cách nhau bằng dấu phẩy. Để trống thời gian có thể học nếu bạn không muốn học trong ngày này.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                color: palette.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: palette.danger,
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: palette.danger,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Hủy',
                    style: TextStyle(
                      color: palette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                MochiPrimaryButton(
                  onPressed: () {
                    try {
                      List<String> parse(String value) {
                        if (value.trim().isEmpty) return [];

                        return value.split(',').map((item) {
                          final range = item.trim();
                          if (range.isEmpty) {
                            throw FormatException();
                          }

                          scheduleRange(range);
                          return range;
                        }).toList();
                      }

                      final free = parse(freeController.text);
                      final busy = parse(busyController.text);
                      final data = routine.toJson();

                      data[isDate ? 'dateFree' : 'weeklyFree'] = {
                        ...(isDate ? routine.dateFree : routine.weeklyFree),
                        key: free,
                      };

                      data[isDate ? 'dateBusy' : 'weeklyBusy'] = {
                        ...(isDate ? routine.dateBusy : routine.weeklyBusy),
                        key: busy,
                      };

                      store.updateDailyRoutine(DailyRoutine.fromJson(data));

                      Navigator.pop(dialogContext);
                    } catch (_) {
                      setDialogState(() {
                        error = 'Định dạng chưa hợp lệ. Hãy sử dụng HH:mm-HH:mm và kiểm tra thứ tự thời gian.';
                      });
                    }
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      freeController.dispose();
      busyController.dispose();
    }
  }

  Widget _buildTimeInput({
    required MochiPalette palette,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: palette.action),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: palette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: palette.ink, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: palette.muted.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            filled: true,
            fillColor: palette.pageTop,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.action, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  String _weeklyFreeText(DailyRoutine routine, String key) {
    final value = routine.weeklyFree.containsKey(key)
        ? routine.weeklyFree[key]!
        : ['${routine.eveningFreeStart}-${routine.eveningFreeEnd}'];

    return value.join(', ');
  }

  String _dateLabel(String date) {
    final parts = date.split('-');

    if (parts.length != 3) return date;

    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );

    if (selectedDate == null || !mounted) return;

    await _editRoutine(
      title: 'Lịch riêng ${selectedDate.day}/${selectedDate.month}',
      key: MochiStore.dateKey(selectedDate),
      isDate: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final routine = store.dailyRoutine;
    final palette = MochiPalette.of(context);

    final dateKeys = {
      ...routine.dateFree.keys,
      ...routine.dateBusy.keys,
    }.toList()..sort();

    return MochiScaffold(
      appBar: MochiAppBar(
        title: 'Lịch sinh hoạt',
        subtitle: 'Sắp xếp thời gian học phù hợp với bạn.',
        large: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          MochiSpacing.xl,
          MochiSpacing.xs,
          MochiSpacing.xl,
          MochiSpacing.xxl,
        ),
        children: [
          _buildOverviewCard(palette),
          SizedBox(height: MochiSpacing.lg),

          _buildSectionHeader(
            palette,
            title: 'Lịch học hàng tuần',
            subtitle: 'Thiết lập thời gian lặp lại cho từng ngày.',
          ),
          SizedBox(height: MochiSpacing.sm),

          MochiCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (int day = 1; day <= 7; day++) ...[
                  _buildWeekdayTile(
                    palette: palette,
                    routine: routine,
                    day: day,
                  ),
                  if (day != 7)
                    Divider(height: 1, indent: 58, color: palette.cardBorder),
                ],
              ],
            ),
          ),

          SizedBox(height: MochiSpacing.lg),

          _buildSectionHeader(
            palette,
            title: 'Lịch riêng theo ngày',
            subtitle: 'Ưu tiên lịch riêng khi trùng với lịch hàng tuần.',
          ),
          SizedBox(height: MochiSpacing.sm),

          _buildDateSection(
            palette: palette,
            dateKeys: dateKeys,
            routine: routine,
          ),

          SizedBox(height: MochiSpacing.md),
          _buildTipCard(palette),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(MochiPalette palette) {
    return MochiCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: palette.primaryGradient,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhịp học của bạn',
                    style: TextStyle(
                      color: palette.onAccent,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chủ động sắp xếp thời gian để Mochii gợi ý lịch học phù hợp hơn.',
                    style: TextStyle(
                      color: palette.onAccent.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.calendar_month_rounded,
              size: 46,
              color: palette.onAccent.withValues(alpha: 0.9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    MochiPalette palette, {
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayTile({
    required MochiPalette palette,
    required DailyRoutine routine,
    required int day,
  }) {
    final key = '$day';
    final freeText = _weeklyFreeText(routine, key);
    final busyText = routine.weeklyBusy[key]?.join(', ') ?? '';
    final hasFreeTime = freeText.isNotEmpty;
    final hasBusyTime = busyText.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _editRoutine(
        title: 'Lịch ${_weekdays[day - 1]}',
        key: key,
        isDate: false,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: hasFreeTime ? palette.softAccent : palette.cardSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: hasFreeTime ? palette.action : palette.muted,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _weekdays[day - 1],
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFreeTime ? freeText : 'Không có giờ học',
                    style: TextStyle(
                      color: hasFreeTime ? palette.action : palette.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasBusyTime) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Bận: $busyText',
                      style: TextStyle(color: palette.muted, fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_calendar_outlined, color: palette.muted, size: 19),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection({
    required MochiPalette palette,
    required List<String> dateKeys,
    required DailyRoutine routine,
  }) {
    return MochiCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dateKeys.isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: palette.softAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.event_note_rounded,
                      color: palette.action,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chưa có lịch riêng',
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bạn có thể thêm lịch nghỉ hoặc điều chỉnh giờ học cho một ngày cụ thể.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16),
                  MochiPrimaryButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Thêm lịch riêng'),
                    onPressed: _selectDate,
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            for (int i = 0; i < dateKeys.length; i++) ...[
              _buildDateTile(
                palette: palette,
                routine: routine,
                date: dateKeys[i],
              ),
              if (i != dateKeys.length - 1)
                Divider(height: 1, color: palette.cardBorder),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDateTile({
    required MochiPalette palette,
    required DailyRoutine routine,
    required String date,
  }) {
    final freeText = routine.dateFree[date]?.join(', ') ?? '';
    final busyText = routine.dateBusy[date]?.join(', ') ?? '';
    final hasFreeTime = freeText.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _editRoutine(
        title: 'Lịch riêng ${_dateLabel(date)}',
        key: date,
        isDate: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: hasFreeTime ? palette.softAccent : palette.cardSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_rounded,
                color: hasFreeTime ? palette.action : palette.muted,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(date),
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFreeTime ? freeText : 'Không có giờ học',
                    style: TextStyle(
                      color: hasFreeTime ? palette.action : palette.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (busyText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Bận: $busyText',
                      style: TextStyle(color: palette.muted, fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(MochiPalette palette) {
    return MochiCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: palette.warning,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mẹo sử dụng lịch',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Lịch riêng theo ngày sẽ được ưu tiên hơn lịch tuần. Những khoảng thời gian bận sẽ giúp Mochii tránh đề xuất nhiệm vụ vào thời điểm đó.',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
