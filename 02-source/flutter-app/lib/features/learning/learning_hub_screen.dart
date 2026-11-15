import '../../design/mochi_design.dart';

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../core/learning/learning_models.dart';
import '../../core/learning/curriculum_catalog.dart';
import '../focus/focus_timer_screen.dart';

class LearningHubScreen extends StatefulWidget {
  final int initialTab;
  const LearningHubScreen({super.key, this.initialTab = 0});
  @override
  State<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends State<LearningHubScreen> {
  void _error(Object e) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
  }

  Future<void> _setup(MochiStore store) async {
    var grade = store.learning.gradeLevel ?? 11;
    final year = TextEditingController(text: store.learning.academicYear);
    final selected = store.learning.courses.map((x) => x.subject).toSet();
    if (selected.isEmpty) selected.add('Toán');
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Lớp và môn đang học'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: grade,
                    decoration: InputDecoration(labelText: 'Lớp'),
                    items: [
                      for (var i = 1; i <= 12; i++)
                        DropdownMenuItem(value: i, child: Text('Lớp $i')),
                    ],
                    onChanged: (v) => setDialog(() => grade = v!),
                  ),
                  TextField(
                    controller: year,
                    decoration: InputDecoration(
                      labelText: 'Năm học',
                      hintText: 'Ví dụ: 2026–2027',
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Chỉ chọn môn bạn thực sự học. Có thể đổi sau.'),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: learningSubjectChoices
                        .map(
                          (subject) => FilterChip(
                            label: Text(subject),
                            selected: selected.contains(subject),
                            onSelected: (on) => setDialog(() {
                              on
                                  ? selected.add(subject)
                                  : selected.remove(subject);
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
            MochiPrimaryButton(
              onPressed: () async {
                if (year.text.trim().isEmpty || selected.isEmpty) {
                  _error('Chọn môn và nhập năm học.');
                  return;
                }
                try {
                  final courses = selected.map((s) {
                    final old = store.learning.courses
                        .where((x) => x.subject == s)
                        .firstOrNull;
                    return grade == store.learning.gradeLevel && old != null
                        ? old
                        : CurriculumCatalog.courseFor(s, grade);
                  }).toList();
                  await store.saveLearningSetup(
                    gradeLevel: grade,
                    academicYear: year.text,
                    courses: courses,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  _error(e);
                }
              },
              child: Text('Lưu hồ sơ'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(Duration(milliseconds: 300));
    year.dispose();
  }

  Future<void> _editCourse(MochiStore store, LearningCourse course) async {
    final book = TextEditingController(text: course.textbook),
        topics = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(course.subject),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: book,
                  decoration: InputDecoration(
                    labelText: 'Bộ sách / tài liệu đang theo học (tùy chọn)',
                  ),
                ),
                TextField(
                  controller: topics,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Thêm chủ đề theo lớp, mỗi dòng một chủ đề',
                    helperText:
                        'Nội dung bạn nhập; không gắn nhãn nguồn đã xác minh.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
          MochiPrimaryButton(
            onPressed: () async {
              final added = topics.text
                  .split('\n')
                  .map((x) => x.trim())
                  .where((x) => x.isNotEmpty)
                  .toSet();
              final updated = LearningCourse(
                id: course.id,
                subject: course.subject,
                textbook: book.text.trim(),
                sourceLabel: course.sourceLabel,
                topics: [
                  ...course.topics,
                  for (final title in added)
                    if (!course.topics.any((x) => x.title == title))
                      LearningTopic(
                        id: '${course.id}/user/${DateTime.now().microsecondsSinceEpoch}/${Uri.encodeComponent(title)}',
                        title: title,
                        sourceRef: 'user-provided',
                      ),
                ],
              );
              store.learning.courses = store.learning.courses
                  .map((x) => x.id == course.id ? updated : x)
                  .toList();
              await store.save();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Lưu'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(Duration(milliseconds: 300));
    book.dispose();
    topics.dispose();
  }

  Future<void> _assignment(MochiStore store) async {
    final title = TextEditingController(),
        minutes = TextEditingController(text: '25');
    var subject = store.learning.courses.firstOrNull?.subject ?? 'Toán',
        kind = 'homework';
    DateTime? due;
    final linked = <String>{}, topicIds = <String>{};
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Bài tập và việc cần học'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
                      labelText: 'Việc cụ thể',
                      hintText: 'Làm bài 1–5 thầy giao',
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: subject,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Môn'),
                    items:
                        {
                              ...learningSubjectChoices,
                              ...store.learning.courses.map((x) => x.subject),
                            }
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (v) => setDialog(() {
                      subject = v!;
                      topicIds.clear();
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Loại việc'),
                    items: [
                      DropdownMenuItem(
                        value: 'homework',
                        child: Text('Bài được giao'),
                      ),
                      DropdownMenuItem(
                        value: 'preparation',
                        child: Text('Chuẩn bị bài trên lớp'),
                      ),
                      DropdownMenuItem(
                        value: 'learn',
                        child: Text('Học phần mới'),
                      ),
                      DropdownMenuItem(
                        value: 'review',
                        child: Text('Ôn lại phần cần luyện'),
                      ),
                      DropdownMenuItem(
                        value: 'practice',
                        child: Text('Luyện mục tiêu'),
                      ),
                      DropdownMenuItem(value: 'mock', child: Text('Luyện đề')),
                    ],
                    onChanged: (v) => setDialog(() => kind = v!),
                  ),
                  TextField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Tổng thời lượng dự kiến (phút)',
                      helperText: 'Việc dài được chia thành các phiên; không tự đánh dấu cả bài xong sau một phiên.',
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.event_outlined),
                    label: Text(
                      due == null
                          ? 'Chọn hạn nộp / cần xong (nếu có)'
                          : 'Hạn: ${due!.day}/${due!.month} ${learningClock(due!.hour * 60 + due!.minute)}',
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(Duration(days: 365)),
                        lastDate: DateTime.now().add(Duration(days: 730)),
                      );
                      if (date == null || !ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null)
                        setDialog(
                          () => due = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                    },
                  ),
                  if (store.goals.isNotEmpty) ...[
                    Text(
                      'Có thể phục vụ nhiều mục tiêu, không nhân đôi công việc:',
                    ),
                    ...store.goals
                        .where((g) => !g.isDone)
                        .map(
                          (g) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(g.title),
                            value: linked.contains(g.id),
                            onChanged: (v) => setDialog(() {
                              v == true
                                  ? linked.add(g.id)
                                  : linked.remove(g.id);
                            }),
                          ),
                        ),
                  ],
                  if ((store.learning.courses
                              .where((x) => x.subject == subject)
                              .firstOrNull
                              ?.topics ??
                          [])
                      .isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Liên kết chủ đề (tùy chọn)'),
                      children: [
                        for (final t
                            in store.learning.courses
                                .firstWhere((x) => x.subject == subject)
                                .topics)
                          CheckboxListTile(
                            dense: true,
                            title: Text(t.title),
                            value: topicIds.contains(t.id),
                            onChanged: (v) => setDialog(() {
                              v == true
                                  ? topicIds.add(t.id)
                                  : topicIds.remove(t.id);
                            }),
                          ),
                      ],
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: MochiPalette.of(context).danger),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
            MochiPrimaryButton(
              onPressed: () {
                final n = int.tryParse(minutes.text.trim());
                if (title.text.trim().isEmpty ||
                    n == null ||
                    n < 1 ||
                    n > 1440) {
                  setDialog(
                    () => error =
                        'Nhập tên việc và thời lượng từ 1 đến 1440 phút.',
                  );
                  return;
                }
                store.addTask(
                  title: title.text.trim(),
                  subject: subject,
                  duration: n,
                  kind: kind,
                  dueAt: due,
                  goalIds: linked.toList(),
                  topicIds: topicIds.toList(),
                );
                Navigator.pop(ctx);
              },
              child: Text('Thêm việc'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(Duration(milliseconds: 300));
    title.dispose();
    minutes.dispose();
  }

  Future<void> _lesson(MochiStore store) async {
    var weekday = DateTime.now().weekday,
        subject = store.learning.courses.firstOrNull?.subject ?? 'Toán';
    TimeOfDay? start, end;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Thêm giờ lên lớp / học thêm'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: subject,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Môn'),
                    items:
                        {
                              ...learningSubjectChoices,
                              ...store.learning.courses.map((x) => x.subject),
                            }
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (v) => setDialog(() => subject = v!),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: weekday,
                    decoration: InputDecoration(labelText: 'Lặp lại hàng tuần'),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(
                          value: d,
                          child: Text(d == 7 ? 'Chủ nhật' : 'Thứ ${d + 1}'),
                        ),
                    ],
                    onChanged: (v) => setDialog(() => weekday = v!),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      MochiButton(
                        label: start == null
                            ? 'Chọn giờ bắt đầu'
                            : start!.format(ctx),
                        variant: MochiButtonVariant.secondary,
                        size: MochiButtonSize.small,
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: start ?? TimeOfDay.now(),
                          );
                          if (t != null) setDialog(() => start = t);
                        },
                      ),
                      const SizedBox(width: 8),
                      MochiButton(
                        label: end == null
                            ? 'Chọn giờ kết thúc'
                            : end!.format(ctx),
                        variant: MochiButtonVariant.secondary,
                        size: MochiButtonSize.small,
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: end ?? TimeOfDay.now(),
                          );
                          if (t != null) setDialog(() => end = t);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nhập giờ thật; không đoán giờ từ số tiết. Giờ ngoài lớp vẫn cần lịch rảnh/bận cá nhân.',
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: MochiPalette.of(context).danger),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
            MochiPrimaryButton(
              onPressed: () async {
                if (start == null || end == null) {
                  setDialog(() => error = 'Chọn đủ giờ bắt đầu và kết thúc.');
                  return;
                }
                try {
                  await store.upsertSchoolLesson(
                    SchoolLesson(
                      id: 'lesson_${DateTime.now().microsecondsSinceEpoch}',
                      subject: subject,
                      weekday: weekday,
                      startTime: learningClock(
                        start!.hour * 60 + start!.minute,
                      ),
                      endTime: learningClock(end!.hour * 60 + end!.minute),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialog(() => error = e.toString());
                }
              },
              child: Text('Lưu giờ học'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _plan(MochiStore store) async {
    try {
      final plan = store.previewUnifiedPlan();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Xem trước lịch chung 7 ngày'),
          content: SizedBox(
            width: 700,
            height: math.min(560, MediaQuery.sizeOf(ctx).height * .58),
            child: ListView(
              children: [
                Text(
                  'Một quỹ giờ cho tất cả môn. Giữ giờ lên lớp, giờ bận và nhiệm vụ đã khóa. Đây là xếp giờ theo ràng buộc, không tự sinh nội dung bài học.',
                ),
                SizedBox(height: 12),
                for (final block in plan.blocks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.schedule_outlined),
                    title: Text(block.title),
                    subtitle: Text(
                      '${block.date} · ${block.startTime} · ${block.minutes} phút · ${block.subject}\n${block.reason}',
                    ),
                  ),
                if (plan.deferred.isNotEmpty) ...[
                  Divider(),
                  Text(
                    'Việc chưa được xếp / giữ nguyên',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final d in plan.deferred)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        store.tasks
                                .where((t) => t.id == d.taskId)
                                .firstOrNull
                                ?.title ??
                            'Nhiệm vụ',
                      ),
                      subtitle: Text(
                        '${d.reason}${d.remainingMinutes > 0 ? ' Còn ${d.remainingMinutes} phút.' : ''}',
                      ),
                    ),
                ],
                if (plan.blocks.isEmpty)
                  Text(
                    'Chưa có phiên có thể xếp. Kiểm tra việc cần làm, giờ rảnh và tổng thời lượng học mỗi ngày.',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Để sau'),
            ),
            MochiPrimaryButton(
              onPressed: plan.blocks.isEmpty
                  ? null
                  : () async {
                      try {
                        await store.acceptUnifiedPlan(plan);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        _error(e);
                      }
                    },
              child: Text('Áp dụng lịch'),
            ),
          ],
        ),
      );
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _importTimetableWithAI(MochiStore store) async {
    final textController = TextEditingController();
    bool isExtracting = false;
    String? error;
    List<Map<String, dynamic>>? previewLessons;
    XFile? pickedImage;
    String? imageBase64;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Nhập thời khóa biểu bằng AI'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dán văn bản hoặc bảng thời khóa biểu của trường/lớp. AI sẽ bóc tách môn, thứ và khung giờ để bạn xem trước trước khi lưu.',
                    style: TextStyle(
                      fontSize: 13,
                      color: MochiPalette.of(context).muted,
                    ),
                  ),
                  SizedBox(height: 12),
                  if (previewLessons == null) ...[
                    if (pickedImage != null)
                      Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MochiPalette.of(context).cardSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MochiPalette.of(context).cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: MochiPalette.of(context).action,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pickedImage!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 18),
                              onPressed: () {
                                setDialog(() {
                                  pickedImage = null;
                                  imageBase64 = null;
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isExtracting
                                  ? null
                                  : () async {
                                      final picker = ImagePicker();
                                      final file = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1600,
                                        maxHeight: 1600,
                                        imageQuality: 85,
                                      );
                                      if (file != null) {
                                        final bytes = await file.readAsBytes();
                                        setDialog(() {
                                          pickedImage = file;
                                          imageBase64 =
                                              'data:image/jpeg;base64,' +
                                              base64Encode(bytes);
                                          error = null;
                                        });
                                      }
                                    },
                              icon: Icon(
                                Icons.photo_library_outlined,
                                size: 18,
                              ),
                              label: Text('Chọn ảnh TKB'),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isExtracting
                                  ? null
                                  : () async {
                                      final picker = ImagePicker();
                                      final file = await picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 1600,
                                        maxHeight: 1600,
                                        imageQuality: 85,
                                      );
                                      if (file != null) {
                                        final bytes = await file.readAsBytes();
                                        setDialog(() {
                                          pickedImage = file;
                                          imageBase64 =
                                              'data:image/jpeg;base64,' +
                                              base64Encode(bytes);
                                          error = null;
                                        });
                                      }
                                    },
                              icon: Icon(Icons.camera_alt_outlined, size: 18),
                              label: Text('Chụp ảnh TKB'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                    ],
                    TextField(
                      controller: textController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Nội dung thời khóa biểu hoặc ghi chú',
                        hintText:
                            'Dán nội dung bảng lớp, hoặc chọn ảnh bên trên...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isExtracting) ...[
                      SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('AI đang bóc tách thời khóa biểu...'),
                        ],
                      ),
                    ],
                  ] else ...[
                    Text(
                      'Đã trích xuất ${previewLessons!.length} tiết học. Bạn có thể kiểm tra trước khi lưu:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: previewLessons!.length,
                        itemBuilder: (c, idx) {
                          final item = previewLessons![idx];
                          final wd = item['weekday'] as int? ?? 1;
                          final dayName = wd == 7
                              ? 'Chủ nhật'
                              : 'Thứ ${wd + 1}';
                          return MochiCard(
                            padding: EdgeInsets.zero,
                            margin: EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                item['subject']?.toString() ?? 'Môn học',
                              ),
                              subtitle: Text(
                                '$dayName · ${item['startTime']} - ${item['endTime']}',
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setDialog(() {
                                    previewLessons!.removeAt(idx);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: MochiPalette.of(context).danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
            if (previewLessons == null)
              MochiPrimaryButton(
                onPressed: isExtracting
                    ? null
                    : () async {
                        final raw = textController.text.trim();
                        FocusManager.instance.primaryFocus?.unfocus();
                        if (raw.isEmpty && imageBase64 == null) {
                          setDialog(
                            () => error = 'Vui lòng chọn ảnh hoặc dán nội dung thời khóa biểu.',
                          );
                          return;
                        }
                        setDialog(() {
                          isExtracting = true;
                          error = null;
                        });
                        try {
                          final res = await store.aiService.extractTimetable(
                            rawContent: raw.isNotEmpty ? raw : null,
                            imageDataUri: imageBase64,
                          );
                          setDialog(() {
                            isExtracting = false;
                            previewLessons = res;
                          });
                        } catch (e) {
                          setDialog(() {
                            isExtracting = false;
                            error = e.toString().replaceFirst(
                              'Bad state: ',
                              '',
                            );
                          });
                        }
                      },
                child: Text('Bóc tách với AI'),
              )
            else
              MochiPrimaryButton(
                onPressed: previewLessons!.isEmpty
                    ? null
                    : () async {
                        try {
                          for (final p in previewLessons!) {
                            final lesson = SchoolLesson(
                              id: 'lesson_${DateTime.now().microsecondsSinceEpoch}_${p['weekday']}_${p['subject']}',
                              subject: p['subject']?.toString() ?? 'Môn học',
                              weekday: p['weekday'] as int? ?? 1,
                              startTime: p['startTime']?.toString() ?? '07:15',
                              endTime: p['endTime']?.toString() ?? '08:00',
                            );
                            await store.upsertSchoolLesson(lesson);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setDialog(() => error = e.toString());
                        }
                      },
                child: Text('Lưu vào thời khóa biểu'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _progress(MochiStore store) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _sectionHeader(context, 'Tổng quan', 'Xem lại tiến độ từng môn đang theo học'),
        const SizedBox(height: 12),
        MochiCard(
          child: MochiStatRow(
            children: [
              MochiStatTile(
                label: 'Môn đang học',
                value: '${store.learning.courses.length}',
                icon: Icons.school_rounded,
                iconTone: MochiChipTone.accent,
              ),
              MochiStatTile(
                label: 'Chủ đề đã vững',
                value: '${store.learning.courses.expand((c) => c.topics).where((t) => store.learning.readinessFor(t.id) == TopicReadiness.confident).length}',
                icon: Icons.check_circle_rounded,
                iconTone: MochiChipTone.success,
              ),
              MochiStatTile(
                label: 'Cần ôn lại',
                value: '${store.learning.courses.expand((c) => c.topics).where((t) => store.learning.readinessFor(t.id) == TopicReadiness.needsReview).length}',
                icon: Icons.refresh_rounded,
                iconTone: MochiChipTone.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...store.learning.courses.map((course) => _courseCard(context, store, course)),
      ],
    );
  }

  Widget _courseCard(BuildContext context, MochiStore store, LearningCourse course) {
    final palette = MochiPalette.of(context);
    final confident = course.topics.where((t) => store.learning.readinessFor(t.id) == TopicReadiness.confident).length;
    final needsReview = course.topics.where((t) => store.learning.readinessFor(t.id) == TopicReadiness.needsReview).length;
    final notStudied = course.topics.where((t) => store.learning.readinessFor(t.id) == TopicReadiness.notStudied).length;
    final total = course.topics.length;
    final pct = total > 0 ? confident / total : 0.0;

    return MochiCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.cardSoft,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.school_rounded, color: palette.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.subject, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.ink)),
                      if (course.textbook.isNotEmpty)
                        Text(course.textbook, style: TextStyle(fontSize: 12, color: palette.muted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: palette.action),
                  onPressed: () => _editCourse(store, course),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tiến độ ${course.subject}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.muted)),
                const SizedBox(height: 4),
                MochiProgressBar(value: pct, showValue: true),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.cardSoft.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
            ),
            child: MochiStatRow(
              children: [
                MochiStatTile(label: 'Vừa', value: '$confident', icon: Icons.check_circle_rounded, iconTone: MochiChipTone.success),
                MochiStatTile(label: 'Cần ôn', value: '$needsReview', icon: Icons.refresh_rounded, iconTone: MochiChipTone.warning),
                MochiStatTile(label: 'Chưa học', value: '$notStudied', icon: Icons.radio_button_unchecked_rounded, iconTone: MochiChipTone.neutral),
              ],
            ),
          ),
          if (course.topics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in course.topics)
                    GestureDetector(
                      onTap: () {
                        final current = store.learning.readinessFor(topic.id);
                        final next = current == TopicReadiness.confident ? TopicReadiness.unknown : TopicReadiness.confident;
                        store.setTopicReadiness(course.id, topic.id, next);
                      },
                      child: MochiChip(
                        label: topic.title.length > 18 ? '${topic.title.substring(0, 18)}...' : topic.title,
                        tone: store.learning.readinessFor(topic.id) == TopicReadiness.confident ? MochiChipTone.accent : MochiChipTone.neutral,
                        compact: true,
                      ),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: MochiPrimaryButton(
                onPressed: () => _editCourse(store, course),
                child: const Text('Thêm chủ đề đang theo học'),
              ),
            ),
        ],
      ),
    );
  }
  Widget _agenda(MochiStore store) {
    final palette = MochiPalette.of(context);
    final plan = store.learning.activePlan;
    final pendingTasks = store.tasks.where((t) => !t.isDone).toList();
    final completedTasks = store.tasks.where((t) => t.isDone).toList();

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            MochiPrimaryButton.icon(
              key: const ValueKey('learning-add-assignment'),
              onPressed: () => _assignment(store),
              icon: const Icon(Icons.add),
              label: const Text('Thêm bài / việc cần học'),
            ),
            MochiButton(
              key: const ValueKey('learning-plan-all'),
              label: 'Xếp lịch chung',
              variant: MochiButtonVariant.secondary,
              size: MochiButtonSize.small,
              onPressed: () => _plan(store),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Ngân sách toàn bộ môn: ${store.dailyRoutine.preferredDailyMinutes} phút/ngày. Đổi trong lịch sinh hoạt.',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),

        if (plan != null) ...[
          _sectionHeader(context, 'Lịch đã áp dụng', null),
          const SizedBox(height: 12),
          for (final block in plan.blocks)
            if (store.tasks.any((t) => t.id == block.taskId && !t.isDone))
              MochiCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(block.title),
                  subtitle: Text(
                    '${block.date} · ${block.startTime} · ${block.minutes} phút · ${block.subject}\nĐã ghi nhận ${store.learning.completedMinutesForBlock(block.id)} phút',
                  ),
                  trailing: IconButton(
                    tooltip: 'Học phần này',
                    icon: Icon(Icons.play_arrow_rounded, color: palette.action),
                    onPressed: () {
                      final task = store.tasks.firstWhere(
                        (t) => t.id == block.taskId,
                      );
                      final data = task.toJson()
                        ..['durationMinutes'] = block.minutes;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FocusTimerScreen(
                            targetTask: TaskModel.fromJson(data),
                            learningBlockId: block.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          const SizedBox(height: 16),
        ],

        if (pendingTasks.isNotEmpty) ...[
          _sectionHeader(context, 'Sắp tới (${pendingTasks.length})', null),
          const SizedBox(height: 12),
          ...pendingTasks.map((task) => _taskCard(context, store, task)),
          const SizedBox(height: 16),
        ],

        if (completedTasks.isNotEmpty) ...[
          _sectionHeader(context, 'Đã hoàn thành (${completedTasks.length})', null),
          const SizedBox(height: 12),
          ...completedTasks.map((task) => _completedTaskCard(context, store, task)),
          const SizedBox(height: 16),
        ],

        if (store.tasks.isEmpty) _emptyState(context, store),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String? subtitle) {
    final palette = MochiPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.ink),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: palette.muted)),
        ],
      ],
    );
  }

  Widget _taskCard(BuildContext context, MochiStore store, TaskModel task) {
    final palette = MochiPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: palette.card,
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
                color: task.isDone ? Colors.transparent : palette.cardBorder,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.ink.withValues(alpha: 0.03),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: task.isDone ? palette.muted : palette.ink,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          if (task.scheduledTime != null && task.scheduledTime!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: palette.action.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.scheduledTime!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: palette.action,
                                ),
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: palette.action.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.subject,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: palette.action,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.durationMinutes} phút',
                            style: TextStyle(fontSize: 12, color: palette.muted),
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
                            builder: (ctx) => FocusTimerScreen(targetTask: task),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 16, color: palette.onAccent),
                          const SizedBox(width: 3),
                          Text('Học ngay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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

  Widget _completedTaskCard(BuildContext context, MochiStore store, TaskModel task) {
    final palette = MochiPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.card,
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            style: TextStyle(fontSize: 12, color: palette.muted),
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

  Widget _emptyState(BuildContext context, MochiStore store) {
    final palette = MochiPalette.of(context);
    return MochiCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: palette.action),
          const SizedBox(height: 12),
          Text(
            'Chưa có bài tập nào',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Thêm việc thật từ lớp hoặc mục tiêu để bắt đầu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.muted),
          ),
          const SizedBox(height: 16),
          MochiPrimaryButton.icon(
            onPressed: () => _assignment(store),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm việc mới'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timetable(MochiStore store) {
    final palette = MochiPalette.of(context);
    final days = <int, List<SchoolLesson>>{};
    for (final lesson in store.learning.timetable) {
      days.putIfAbsent(lesson.weekday, () => <SchoolLesson>[]).add(lesson);
    }
    final sortedDays = days.keys.toList()..sort();

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _sectionHeader(context, 'Giờ học thực tế', 'Các khoảng này được loại khỏi giờ có thể tự học.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            MochiPrimaryButton.icon(
              onPressed: () => _lesson(store),
              icon: const Icon(Icons.add),
              label: const Text('Thêm giờ lên lớp'),
            ),
            MochiButton(
              label: 'Nhập TKB bằng AI',
              variant: MochiButtonVariant.secondary,
              size: MochiButtonSize.small,
              onPressed: () => _importTimetableWithAI(store),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (sortedDays.isEmpty)
          _emptyState(context, store)
        else ..._buildDayCards(store, palette, sortedDays, days),
      ],
    );
  }

  List<Widget> _buildDayCards(
    MochiStore store,
    MochiPalette palette,
    List<int> sortedDays,
    Map<int, List<SchoolLesson>> days,
  ) {
    return sortedDays.map((wd) {
      final dayLessons = days[wd]!..sort(
        (a, b) => int.parse(a.startTime.replaceAll(':', ''))
            .compareTo(int.parse(b.startTime.replaceAll(':', ''))),
      );
      final dayName = wd == 7 ? 'Chủ nhật' : 'Thứ ${wd + 1}';
      return MochiCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        dayName == 'Chủ nhật' ? 'CN' : dayName.replaceAll('Thứ ', ''),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dayName,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.ink),
                  ),
                ],
              ),
            ),
            ...dayLessons.map((lesson) => ListTile(
              dense: true,
              title: Text(lesson.subject),
              subtitle: Text('${lesson.startTime}–${lesson.endTime}'),
              leading: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
              trailing: IconButton(
                tooltip: 'Xóa giờ học',
                icon: Icon(Icons.delete_outline, color: palette.muted, size: 20),
                onPressed: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Xóa giờ học này?'),
                      content: Text('${lesson.subject} · ${lesson.startTime}–${lesson.endTime}'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Giữ lại'),
                        ),
                        MochiPrimaryButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) await store.removeSchoolLesson(lesson.id);
                },
              ),
            )),
          ],
        ),
      );
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final palette = MochiPalette.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Học tập cá nhân'),
          actions: [
            IconButton(
              tooltip: 'Thiết lập lớp và môn học',
              icon: Icon(Icons.tune_rounded),
              onPressed: () => _setup(store),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: palette.action,
            indicatorWeight: 3,
            labelColor: palette.action,
            unselectedLabelColor: palette.muted,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: [
              Tab(text: 'Tiến độ môn'),
              Tab(text: 'Bài & lịch chung'),
              Tab(text: 'Thời khóa biểu'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (store.learning.gradeLevel == null)
              Material(
                color: MochiPalette.of(context).softAccent,
                child: ListTile(
                  title: Text('Chọn lớp và các môn bạn đang học'),
                  subtitle: Text(
                    'Đánh dấu tiến độ một lần, cập nhật dần theo bài trên lớp.',
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _setup(store),
                ),
              ),
            if (store.cloudService.hasActiveUser && !store.isCloudSynced)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'Thay đổi đang chờ đồng bộ hoặc cần kết nối lại.',
                  style: TextStyle(
                    fontSize: 12,
                    color: MochiPalette.of(context).muted,
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [_progress(store), _agenda(store), _timetable(store)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
