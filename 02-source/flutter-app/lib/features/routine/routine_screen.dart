import '../../design/mochi_design.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../core/services/study_schedule.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});
  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  Future<void> edit(String label, String key, bool date) async {
    final store = context.read<MochiStore>(),
        r = context.read<MochiStore>().dailyRoutine;
    final free = TextEditingController(
      text:
          (date ? r.dateFree[key] : r.weeklyFree[key])?.join(', ') ??
          (date ? '' : '${r.eveningFreeStart}-${r.eveningFreeEnd}'),
    );
    final busy = TextEditingController(
      text: (date ? r.dateBusy[key] : r.weeklyBusy[key])?.join(', ') ?? '',
    );
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(label),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nhập nhiều khung giờ cách nhau bằng dấu phẩy. Để trống giờ rảnh nghĩa là không học ngày này.',
                ),
                TextField(
                  controller: free,
                  decoration: InputDecoration(
                    labelText: 'Giờ có thể học',
                    hintText: '09:00-10:00, 19:30-21:00',
                  ),
                ),
                TextField(
                  controller: busy,
                  decoration: InputDecoration(
                    labelText: 'Giờ bận cần loại trừ',
                    hintText: '19:45-20:15',
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: MochiPalette.of(context).danger),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
            MochiPrimaryButton(
              onPressed: () {
                try {
                  List<String> parse(String s) => s.trim().isEmpty
                      ? []
                      : s.split(',').map((v) {
                          scheduleRange(v.trim());
                          return v.trim();
                        }).toList();
                  final f = parse(free.text),
                      b = parse(busy.text),
                      data = r.toJson();
                  data[date ? 'dateFree' : 'weeklyFree'] = {
                    ...(date ? r.dateFree : r.weeklyFree),
                    key: f,
                  };
                  data[date ? 'dateBusy' : 'weeklyBusy'] = {
                    ...(date ? r.dateBusy : r.weeklyBusy),
                    key: b,
                  };
                  store.updateDailyRoutine(DailyRoutine.fromJson(data));
                  Navigator.pop(ctx);
                } catch (_) {
                  setDialog(
                    () => error = 'Kiểm tra định dạng HH:mm-HH:mm và thứ tự bắt đầu/kết thúc.',
                  );
                }
              },
              child: Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.watch<MochiStore>().dailyRoutine;
    return Scaffold(
      appBar: AppBar(title: Text('Lịch sinh hoạt cá nhân')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            'Lịch tuần',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Lặp lại hàng tuần. Lịch riêng theo ngày sẽ ghi đè lịch tuần; AI không tự bịa thời gian rảnh.',
          ),
          for (var d = 1; d <= 7; d++)
            ListTile(
              title: Text(d == 7 ? 'Chủ nhật' : 'Thứ ${d + 1}'),
              subtitle: Text(
                (r.weeklyFree['$d'] ??
                            ['${r.eveningFreeStart}-${r.eveningFreeEnd}'])
                        .join(', ')
                        .isEmpty
                    ? 'Không có giờ học'
                    : (r.weeklyFree['$d'] ??
                              ['${r.eveningFreeStart}-${r.eveningFreeEnd}'])
                          .join(', '),
              ),
              trailing: Icon(Icons.edit_calendar_outlined),
              onTap: () =>
                  edit(d == 7 ? 'Chủ nhật' : 'Thứ ${d + 1}', '$d', false),
            ),
          Divider(),
          Text(
            'Lịch riêng trong tháng',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          MochiPrimaryButton.icon(
            icon: Icon(Icons.calendar_month_outlined),
            label: Text('Chọn ngày để điều chỉnh'),
            onPressed: () async {
              final day = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now().subtract(Duration(days: 1)),
                lastDate: DateTime.now().add(Duration(days: 730)),
              );
              if (day != null && mounted)
                await edit(
                  'Lịch riêng ${day.day}/${day.month}',
                  MochiStore.dateKey(day),
                  true,
                );
            },
          ),
          for (final date in r.dateFree.keys)
            ListTile(
              title: Text(date),
              subtitle: Text(
                r.dateFree[date]!.isEmpty
                    ? 'Không học'
                    : r.dateFree[date]!.join(', '),
              ),
              onTap: () => edit(date, date, true),
            ),
        ],
      ),
    );
  }
}
