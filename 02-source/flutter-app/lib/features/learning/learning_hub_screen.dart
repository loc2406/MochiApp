import '../../design/mochi_design.dart';

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _setup(MochiStore store) async {
    var grade = store.learning.gradeLevel ?? 11;
    final year = TextEditingController(text: store.learning.academicYear);
    final selected = store.learning.courses.map((x) => x.subject).toSet();
    if (selected.isEmpty) selected.add('Toán');
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => MochiFormDialog(
          title: 'Lớp và môn đang học',
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MochiDropdownField<int>(
                    value: grade,
                    label: 'Lớp',
                    items: [
                      for (var i = 1; i <= 12; i++)
                        DropdownMenuItem(value: i, child: Text('Lớp $i')),
                    ],
                    onChanged: (v) => setDialog(() => grade = v!),
                  ),
                  MochiTextField(
                    controller: year,
                    label: 'Năm học',
                    hint: 'Ví dụ: 2026–2027',
                  ),
                  SizedBox(height: 16),
                  Text('Chỉ chọn môn bạn thực sự học. Có thể đổi sau.'),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: learningSubjectChoices
                        .map(
                          (subject) => MochiFilterChip(
                            label: subject,
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
            MochiButton(
              label: 'Hủy',
              variant: MochiButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
            MochiButton(
              label: 'Lưu hồ sơ',
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
                    if (grade == store.learning.gradeLevel && old != null) {
                      return old;
                    }

                    final catalog = CurriculumCatalog.courseFor(
                      s,
                      grade,
                      textbook: old?.textbook ?? '',
                    );
                    if (old == null) return catalog;

                    final catalogTitles = catalog.topics
                        .map((topic) => topic.title.trim().toLowerCase())
                        .toSet();
                    final userTopics = old.topics.where(
                      (topic) =>
                          topic.sourceRef == 'user-provided' &&
                          !catalogTitles.contains(
                            topic.title.trim().toLowerCase(),
                          ),
                    );
                    return LearningCourse(
                      id: catalog.id,
                      subject: catalog.subject,
                      textbook: old.textbook,
                      sourceLabel: catalog.sourceLabel,
                      topics: [...catalog.topics, ...userTopics],
                    );
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
      builder: (ctx) => MochiFormDialog(
        title: course.subject,
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MochiTextField(
                  controller: book,
                  label: 'Bộ sách / tài liệu đang theo học (tùy chọn)',
                ),
                const SizedBox(height: MochiSpacing.sm),
                MochiTextField(
                  controller: topics,
                  maxLines: 5,
                  label: 'Thêm chủ đề theo lớp, mỗi dòng một chủ đề',
                  hint: 'Nội dung bạn nhập; không gắn nhãn nguồn đã xác minh.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          MochiButton(
            label: 'Hủy',
            variant: MochiButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          MochiButton(
            label: 'Lưu',
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
        builder: (ctx, setDialog) => MochiFormDialog(
          title: 'Bài tập và việc cần học',
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MochiTextField(
                    controller: title,
                    label: 'Việc cụ thể',
                    hint: 'Làm bài 1–5 thầy giao',
                  ),
                  SizedBox(height: 12),
                  MochiDropdownField<String>(
                    value: subject,
                    isExpanded: true,
                    label: 'Môn',
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
                  MochiDropdownField<String>(
                    value: kind,
                    isExpanded: true,
                    label: 'Loại việc',
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
                  MochiTextField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    label: 'Tổng thời lượng dự kiến (phút)',
                    hint: '25',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: MochiSpacing.xs),
                    child: Text(
                      'Việc dài được chia thành nhiều phiên; một phiên không tự đánh dấu cả bài hoàn thành.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: MochiPalette.of(context).muted),
                    ),
                  ),
                  const SizedBox(height: MochiSpacing.sm),
                  MochiButton(
                    icon: Icons.event_outlined,
                    label: due == null
                        ? 'Chọn hạn hoàn thành (nếu có)'
                        : 'Hạn: ${due!.day}/${due!.month} ${learningClock(due!.hour * 60 + due!.minute)}',
                    variant: MochiButtonVariant.secondary,
                    size: MochiButtonSize.small,
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
                      if (time != null) {
                        setDialog(
                          () => due = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
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
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: MochiPalette.of(context).danger),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            MochiButton(
              label: 'Hủy',
              variant: MochiButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
            MochiButton(
              label: 'Thêm việc',
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
        builder: (ctx, setDialog) => MochiFormDialog(
          title: 'Thêm giờ lên lớp / học thêm',
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MochiDropdownField<String>(
                    value: subject,
                    isExpanded: true,
                    label: 'Môn',
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
                  MochiDropdownField<int>(
                    value: weekday,
                    label: 'Lặp lại hàng tuần',
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
            MochiButton(
              label: 'Hủy',
              variant: MochiButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
            MochiButton(
              label: 'Lưu giờ học',
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
            ),
          ],
        ),
      ),
    );
  }

  String _timetableImageDataUri(XFile file, List<int> bytes) {
    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => throw FormatException(
        'Định dạng ảnh .$extension chưa được hỗ trợ. Hãy dùng JPG, PNG, WEBP hoặc GIF.',
      ),
    };
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  Future<void> _plan(MochiStore store) async {
    try {
      final plan = store.previewUnifiedPlan();
      await showDialog<void>(
        context: context,
        builder: (ctx) => MochiFormDialog(
          title: 'Xem trước lịch chung 7 ngày',
          maxWidth: 700,
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
            MochiButton(
              label: 'Để sau',
              variant: MochiButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
            MochiButton(
              label: 'Áp dụng lịch',
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
    bool isBusy = false;
    bool isSaving = false;
    String? error;
    List<Map<String, dynamic>>? previewLessons;
    XFile? pickedImage;
    String? imageBase64;

    try {
      await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => PopScope(
          canPop: !isBusy,
          child: MochiFormDialog(
          title: 'Nhập thời khóa biểu bằng AI',
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
                            MochiIconButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Bỏ ảnh đã chọn',
                              size: 36,
                              onPressed: isBusy ? null : () {
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
                      Wrap(
                        spacing: MochiSpacing.sm,
                        runSpacing: MochiSpacing.sm,
                        children: [
                          MochiButton(
                            variant: MochiButtonVariant.secondary,
                            size: MochiButtonSize.small,
                            onPressed: isBusy
                                ? null
                                : () async {
                                    setDialog(() => isBusy = true);
                                    try {
                                      final file = await ImagePicker().pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1600,
                                        maxHeight: 1600,
                                        imageQuality: 85,
                                      );
                                      if (file == null || !ctx.mounted) return;
                                      final bytes = await file.readAsBytes();
                                      if (!ctx.mounted) return;
                                      final dataUri = _timetableImageDataUri(
                                        file,
                                        bytes,
                                      );
                                      setDialog(() {
                                        pickedImage = file;
                                        imageBase64 = dataUri;
                                        error = null;
                                      });
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setDialog(() => error = e.toString());
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialog(() => isBusy = false);
                                      }
                                    }
                                  },
                            icon: Icons.photo_library_outlined,
                            label: 'Chọn ảnh TKB',
                          ),
                          MochiButton(
                            variant: MochiButtonVariant.secondary,
                            size: MochiButtonSize.small,
                            onPressed: isBusy
                                ? null
                                : () async {
                                    setDialog(() => isBusy = true);
                                    try {
                                      final file = await ImagePicker().pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 1600,
                                        maxHeight: 1600,
                                        imageQuality: 85,
                                      );
                                      if (file == null || !ctx.mounted) return;
                                      final bytes = await file.readAsBytes();
                                      if (!ctx.mounted) return;
                                      final dataUri = _timetableImageDataUri(
                                        file,
                                        bytes,
                                      );
                                      setDialog(() {
                                        pickedImage = file;
                                        imageBase64 = dataUri;
                                        error = null;
                                      });
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setDialog(() => error = e.toString());
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialog(() => isBusy = false);
                                      }
                                    }
                                  },
                            icon: Icons.camera_alt_outlined,
                            label: 'Chụp ảnh TKB',
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                    ],
                    MochiTextField(
                      controller: textController,
                      maxLines: 4,
                      label: 'Nội dung thời khóa biểu hoặc ghi chú',
                      hint: 'Dán nội dung bảng lớp, hoặc chọn ảnh bên trên...',
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
                              trailing: MochiIconButton(
                                icon: Icons.remove_circle_outline_rounded,
                                tooltip: 'Bỏ tiết học này',
                                color: MochiPalette.of(context).danger,
                                filled: false,
                                size: 38,
                                onPressed: isBusy ? null : () {
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
            MochiButton(
              label: 'Hủy',
              variant: MochiButtonVariant.secondary,
              onPressed: isBusy ? null : () => Navigator.pop(ctx),
            ),
            if (previewLessons == null)
              MochiButton(
                label: isExtracting ? 'Đang bóc tách…' : 'Bóc tách với AI',
                icon: Icons.auto_awesome_rounded,
                loading: isExtracting,
                onPressed: isBusy
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
                          isBusy = true;
                          isExtracting = true;
                          error = null;
                        });
                        try {
                          final res = await store.aiService.extractTimetable(
                            rawContent: raw.isNotEmpty ? raw : null,
                            imageDataUri: imageBase64,
                          );
                          if (!ctx.mounted) return;
                          setDialog(() {
                            isExtracting = false;
                            isBusy = false;
                            if (res.isEmpty) {
                              error = 'AI chưa nhận diện được tiết học. Hãy kiểm tra nội dung rồi thử lại.';
                            } else {
                              previewLessons = res;
                            }
                          });
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialog(() {
                              isExtracting = false;
                              isBusy = false;
                              error = e.toString().replaceFirst(
                                'Bad state: ',
                                '',
                              );
                            });
                          }
                        }
                      },
              )
            else
              MochiButton(
                label: isSaving
                    ? 'Đang lưu thời khóa biểu…'
                    : 'Lưu vào thời khóa biểu',
                loading: isSaving,
                onPressed: previewLessons!.isEmpty || isBusy
                    ? null
                    : () async {
                        setDialog(() {
                          isBusy = true;
                          isSaving = true;
                          error = null;
                        });
                        try {
                          final batchId = DateTime.now().microsecondsSinceEpoch;
                          final lessons = List<SchoolLesson>.generate(
                            previewLessons!.length,
                            (i) {
                              final item = previewLessons![i];
                              return SchoolLesson(
                                id: 'lesson_${batchId}_$i',
                                subject:
                                    item['subject']?.toString() ?? 'Môn học',
                                weekday: item['weekday'] as int? ?? 1,
                                startTime:
                                    item['startTime']?.toString() ?? '07:15',
                                endTime:
                                    item['endTime']?.toString() ?? '08:00',
                              );
                            },
                          );
                          final saved = await store.upsertSchoolLessons(lessons);
                          if (!ctx.mounted) return;
                          setDialog(() {
                            isBusy = false;
                            isSaving = false;
                          });
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  saved == 0
                                      ? 'Thời khóa biểu này đã có sẵn.'
                                      : 'Đã lưu $saved tiết học; các tiết trùng đã được bỏ qua.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialog(() {
                              isBusy = false;
                              isSaving = false;
                              error = e.toString().replaceFirst(
                                'Bad state: ',
                                '',
                              );
                            });
                          }
                        }
                      },
              ),
          ],
          ),
        ),
      ),
      );
    } finally {
      textController.dispose();
    }
  }

  String _readinessLabel(TopicReadiness readiness) => switch (readiness) {
    TopicReadiness.unknown => 'Chưa đánh giá',
    TopicReadiness.notStudied => 'Chưa học',
    TopicReadiness.needsReview => 'Cần ôn',
    TopicReadiness.confident => 'Đã vững',
  };

  MochiChipTone _readinessTone(TopicReadiness readiness) => switch (readiness) {
    TopicReadiness.unknown => MochiChipTone.neutral,
    TopicReadiness.notStudied => MochiChipTone.low,
    TopicReadiness.needsReview => MochiChipTone.warning,
    TopicReadiness.confident => MochiChipTone.success,
  };

  IconData _readinessIcon(TopicReadiness readiness) => switch (readiness) {
    TopicReadiness.unknown => Icons.help_outline_rounded,
    TopicReadiness.notStudied => Icons.radio_button_unchecked_rounded,
    TopicReadiness.needsReview => Icons.refresh_rounded,
    TopicReadiness.confident => Icons.check_circle_rounded,
  };

  Widget _progress(MochiStore store) {
    final allTopics = store.learning.courses.expand((c) => c.topics);
    final confidentCount = allTopics
        .where(
          (topic) =>
              store.learning.readinessFor(topic.id) ==
              TopicReadiness.confident,
        )
        .length;
    final needsReviewCount = allTopics
        .where(
          (topic) =>
              store.learning.readinessFor(topic.id) ==
              TopicReadiness.needsReview,
        )
        .length;
    final notStudiedCount = allTopics
        .where(
          (topic) =>
              store.learning.readinessFor(topic.id) ==
              TopicReadiness.notStudied,
        )
        .length;
    final unknownCount = allTopics
        .where(
          (topic) =>
              store.learning.readinessFor(topic.id) == TopicReadiness.unknown,
        )
        .length;

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _sectionHeader(
          context,
          'Tổng quan',
          'Xem lại tiến độ từng môn đang theo học',
        ),
        const SizedBox(height: 12),
        MochiCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 920
                  ? 5
                  : constraints.maxWidth >= 600
                  ? 3
                  : constraints.maxWidth >= 340
                  ? 2
                  : 1;
              const gap = MochiSpacing.sm;
              final itemWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              final metrics = <Widget>[
                MochiStatTile(
                  label: 'Môn đang học',
                  value: '${store.learning.courses.length}',
                  icon: Icons.school_rounded,
                  iconTone: MochiChipTone.accent,
                  dense: true,
                ),
                MochiStatTile(
                  label: 'Đã vững',
                  value: '$confidentCount',
                  icon: Icons.check_circle_rounded,
                  iconTone: MochiChipTone.success,
                  dense: true,
                ),
                MochiStatTile(
                  label: 'Cần ôn',
                  value: '$needsReviewCount',
                  icon: Icons.refresh_rounded,
                  iconTone: MochiChipTone.warning,
                  dense: true,
                ),
                MochiStatTile(
                  label: 'Chưa học',
                  value: '$notStudiedCount',
                  icon: Icons.radio_button_unchecked_rounded,
                  iconTone: MochiChipTone.neutral,
                  dense: true,
                ),
                MochiStatTile(
                  label: 'Chưa đánh giá',
                  value: '$unknownCount',
                  icon: Icons.help_outline_rounded,
                  iconTone: MochiChipTone.neutral,
                  dense: true,
                ),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final metric in metrics)
                    SizedBox(width: itemWidth, child: metric),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ...store.learning.courses.map(
          (course) => _courseCard(context, store, course),
        ),
      ],
    );
  }

  Widget _courseCard(
    BuildContext context,
    MochiStore store,
    LearningCourse course,
  ) {
    final palette = MochiPalette.of(context);
    final confident = course.topics
        .where(
          (t) => store.learning.readinessFor(t.id) == TopicReadiness.confident,
        )
        .length;
    final needsReview = course.topics
        .where(
          (t) =>
              store.learning.readinessFor(t.id) == TopicReadiness.needsReview,
        )
        .length;
    final notStudied = course.topics
        .where(
          (t) => store.learning.readinessFor(t.id) == TopicReadiness.notStudied,
        )
        .length;
    final notAssessed = course.topics
        .where(
          (t) => store.learning.readinessFor(t.id) == TopicReadiness.unknown,
        )
        .length;
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
                  child: Icon(
                    Icons.school_rounded,
                    color: palette.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.subject,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: palette.ink,
                        ),
                      ),
                      if (course.textbook.isNotEmpty)
                        Text(
                          course.textbook,
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                    ],
                  ),
                ),
                MochiIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Chỉnh sửa môn ${course.subject}',
                  filled: false,
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
                Text(
                  'Tiến độ ${course.subject}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                  ),
                ),
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
            child: Column(
              children: [
                MochiStatRow(
                  children: [
                    MochiStatTile(
                      label: 'Đã vững',
                      value: '$confident',
                      icon: Icons.check_circle_rounded,
                      iconTone: MochiChipTone.success,
                    ),
                    MochiStatTile(
                      label: 'Cần ôn',
                      value: '$needsReview',
                      icon: Icons.refresh_rounded,
                      iconTone: MochiChipTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: MochiSpacing.sm),
                MochiStatRow(
                  children: [
                    MochiStatTile(
                      label: 'Chưa học',
                      value: '$notStudied',
                      icon: Icons.radio_button_unchecked_rounded,
                      iconTone: MochiChipTone.neutral,
                    ),
                    MochiStatTile(
                      label: 'Chưa đánh giá',
                      value: '$notAssessed',
                      icon: Icons.help_outline_rounded,
                      iconTone: MochiChipTone.neutral,
                    ),
                  ],
                ),
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
                    Builder(
                      builder: (context) {
                        final readiness =
                            store.learning.readinessFor(topic.id);
                        return PopupMenuButton<TopicReadiness>(
                          tooltip: 'Cập nhật trạng thái ${topic.title}',
                          onSelected: (value) async {
                            try {
                              await store.setTopicReadiness(
                                course.id,
                                topic.id,
                                value,
                              );
                            } catch (e) {
                              _error(e);
                            }
                          },
                          itemBuilder: (context) => [
                            for (final value in TopicReadiness.values)
                              PopupMenuItem(
                                value: value,
                                child: Row(
                                  children: [
                                    Icon(_readinessIcon(value), size: 18),
                                    const SizedBox(width: MochiSpacing.sm),
                                    Text(_readinessLabel(value)),
                                  ],
                                ),
                              ),
                          ],
                          child: MochiChip(
                            label:
                                '${topic.title} · ${_readinessLabel(readiness)}',
                            icon: _readinessIcon(readiness),
                            tone: _readinessTone(readiness),
                            compact: true,
                          ),
                        );
                      },
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: MochiButton(
                label: 'Thêm chủ đề đang theo học',
                icon: Icons.add_rounded,
                variant: MochiButtonVariant.secondary,
                onPressed: () => _editCourse(store, course),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgendaActions(MochiStore store) {
    const planLabel = 'Xếp lịch chung';
    const assignmentLabel = 'Thêm bài / việc cần học';
    const buttonGap = 12.0;
    const buttonChromeWidth = 67.0;
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    double naturalButtonWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: textDirection,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width + buttonChromeWidth;
      painter.dispose();
      return width;
    }

    final planWidth = naturalButtonWidth(planLabel);
    final assignmentWidth = naturalButtonWidth(assignmentLabel);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsInRow =
            planWidth + assignmentWidth + buttonGap <= constraints.maxWidth;
        final planButton = MochiButton(
          key: const ValueKey('learning-plan-all'),
          label: planLabel,
          icon: Icons.calendar_today_rounded,
          variant: MochiButtonVariant.secondary,
          size: MochiButtonSize.small,
          expand: true,
          onPressed: () => _plan(store),
        );
        final assignmentButton = MochiButton(
          key: const ValueKey('learning-add-assignment'),
          label: assignmentLabel,
          icon: Icons.add_rounded,
          size: MochiButtonSize.small,
          expand: true,
          onPressed: () => _assignment(store),
        );

        if (!fitsInRow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              planButton,
              const SizedBox(height: 8),
              assignmentButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: (planWidth * 100).round(), child: planButton),
            const SizedBox(width: buttonGap),
            Expanded(
              flex: (assignmentWidth * 100).round(),
              child: assignmentButton,
            ),
          ],
        );
      },
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
        _buildAgendaActions(store),
        const SizedBox(height: 16),
        if (plan == null && store.learning.plans.isNotEmpty) ...[
          MochiCard(
            color: palette.warningSoft,
            elevated: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final message = Text(
                  'Lịch cũ không còn áp dụng sau khi thay đổi môn học, tiến độ hoặc thời khóa biểu. Hãy xếp và áp dụng lịch mới để cập nhật các phiên học.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.ink,
                    height: 1.4,
                  ),
                );
                final button = MochiButton(
                  label: 'Xếp lịch mới',
                  icon: Icons.refresh_rounded,
                  size: MochiButtonSize.small,
                  onPressed: () => _plan(store),
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [message, const SizedBox(height: MochiSpacing.sm), button],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: message),
                    const SizedBox(width: MochiSpacing.md),
                    button,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
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
                  trailing: MochiIconButton(
                    tooltip: 'Học phần này',
                    icon: Icons.play_arrow_rounded,
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
          _sectionHeader(
            context,
            'Việc chưa hoàn thành (${pendingTasks.length})',
            null,
          ),
          const SizedBox(height: 12),
          ...pendingTasks.map((task) => _taskCard(context, store, task)),
          const SizedBox(height: 16),
        ],

        if (completedTasks.isNotEmpty) ...[
          _sectionHeader(
            context,
            'Đã hoàn thành (${completedTasks.length})',
            null,
          ),
          const SizedBox(height: 12),
          ...completedTasks.map(
            (task) => _completedTaskCard(context, store, task),
          ),
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: palette.ink,
          ),
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
    return MochiCard(
      margin: const EdgeInsets.only(bottom: MochiSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: MochiSpacing.sm,
        vertical: MochiSpacing.xs,
      ),
      onTap: () => store.toggleTask(task.id, !task.isDone),
      child: Row(
        children: [
          Checkbox(
            value: task.isDone,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            activeColor: palette.action,
            onChanged: (val) => store.toggleTask(task.id, val ?? false),
          ),
          const SizedBox(width: MochiSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: task.isDone ? palette.muted : palette.ink,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: MochiSpacing.xs),
                Wrap(
                  spacing: MochiSpacing.xs,
                  runSpacing: MochiSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (task.scheduledTime?.isNotEmpty == true)
                      MochiChip(
                        label: task.scheduledTime!,
                        icon: Icons.schedule_rounded,
                        tone: MochiChipTone.accent,
                        compact: true,
                      ),
                    if (task.dueAt != null)
                      MochiChip(
                        label:
                            'Hạn ${task.dueAt!.day}/${task.dueAt!.month} · ${learningClock(task.dueAt!.hour * 60 + task.dueAt!.minute)}',
                        icon: Icons.event_outlined,
                        tone: task.dueAt!.isBefore(DateTime.now())
                            ? MochiChipTone.danger
                            : MochiChipTone.warning,
                        compact: true,
                      ),
                    MochiChip(
                      label: task.subject,
                      tone: MochiChipTone.accent,
                      compact: true,
                    ),
                    MochiChip(
                      label: '${task.durationMinutes} phút',
                      tone: MochiChipTone.neutral,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!task.isDone) ...[
            const SizedBox(width: MochiSpacing.xs),
            MochiButton(
              label: 'Học ngay',
              icon: Icons.play_arrow_rounded,
              size: MochiButtonSize.small,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => FocusTimerScreen(targetTask: task),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _completedTaskCard(
    BuildContext context,
    MochiStore store,
    TaskModel task,
  ) {
    final palette = MochiPalette.of(context);
    return MochiCard(
      margin: const EdgeInsets.only(bottom: MochiSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: MochiSpacing.sm,
        vertical: MochiSpacing.xs,
      ),
      onTap: () => store.toggleTask(task.id, !task.isDone),
      child: Row(
        children: [
          Checkbox(
            value: true,
            activeColor: palette.action,
            onChanged: (val) => store.toggleTask(task.id, val ?? false),
          ),
          const SizedBox(width: MochiSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: MochiSpacing.xs),
                Wrap(
                  spacing: MochiSpacing.xs,
                  runSpacing: MochiSpacing.xs,
                  children: [
                    MochiChip(
                      label: task.subject,
                      tone: MochiChipTone.neutral,
                      compact: true,
                    ),
                    MochiChip(
                      label: '${task.durationMinutes} phút',
                      tone: MochiChipTone.neutral,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thêm việc thật từ lớp hoặc mục tiêu để bắt đầu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.muted),
          ),
          const SizedBox(height: 16),
          MochiButton(
            onPressed: () => _assignment(store),
            icon: Icons.add_rounded,
            label: 'Thêm việc mới',
          ),
        ],
      ),
    );
  }

  Widget _timetableActions(MochiStore store) => LayoutBuilder(
    builder: (context, constraints) {
      final importButton = MochiButton(
        label: 'Nhập TKB bằng AI',
        icon: Icons.auto_awesome_rounded,
        variant: MochiButtonVariant.secondary,
        size: MochiButtonSize.small,
        expand: constraints.maxWidth < 440,
        onPressed: () => _importTimetableWithAI(store),
      );
      final addButton = MochiButton(
        onPressed: () => _lesson(store),
        icon: Icons.add_rounded,
        size: MochiButtonSize.small,
        label: 'Thêm giờ lên lớp',
        expand: constraints.maxWidth < 440,
      );
      if (constraints.maxWidth < 440) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            importButton,
            const SizedBox(height: MochiSpacing.sm),
            addButton,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: importButton),
          const SizedBox(width: MochiSpacing.sm),
          Expanded(child: addButton),
        ],
      );
    },
  );

  Widget _timetableEmptyState(MochiStore store) {
    final palette = MochiPalette.of(context);
    return MochiCard(
      padding: const EdgeInsets.all(MochiSpacing.lg),
      child: Column(
        children: [
          Icon(Icons.calendar_month_outlined, size: 42, color: palette.action),
          const SizedBox(height: MochiSpacing.sm),
          Text(
            'Chưa có giờ học nào trong thời khóa biểu',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: MochiSpacing.xs),
          Text(
            'Thêm giờ lên lớp hoặc nhập thời khóa biểu để Mochi tránh xếp lịch tự học trùng giờ.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: MochiSpacing.md),
          MochiButton(
            label: 'Thêm giờ lên lớp',
            icon: Icons.add_rounded,
            onPressed: () => _lesson(store),
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
        _sectionHeader(
          context,
          'Giờ học thực tế',
          'Các khoảng này được loại khỏi giờ có thể tự học.',
        ),
        const SizedBox(height: 12),
        _timetableActions(store),
        const SizedBox(height: 16),
        if (sortedDays.isEmpty)
          _timetableEmptyState(store)
        else
          ..._buildDayCards(store, palette, sortedDays, days),
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
      final dayLessons = days[wd]!
        ..sort(
          (a, b) =>
              int.parse(a.startTime.replaceAll(':', ''))
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
                        dayName == 'Chủ nhật'
                            ? 'CN'
                            : dayName.replaceAll('Thứ ', ''),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
            ),
            ...dayLessons.map(
              (lesson) => ListTile(
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
                trailing: MochiIconButton(
                  tooltip: 'Xóa giờ học',
                  icon: Icons.delete_outline_rounded,
                  color: palette.muted,
                  onPressed: () async {
                    final yes = await MochiDialog.show(
                      context,
                      title: 'Xóa giờ học này?',
                      message:
                          '${lesson.subject} · ${lesson.startTime}–${lesson.endTime}',
                      confirmLabel: 'Xóa',
                      destructive: true,
                      icon: Icons.delete_outline_rounded,
                    );
                    if (yes == true) await store.removeSchoolLesson(lesson.id);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: MochiAppBar.detail(
              title: 'Học tập cá nhân',
              subtitle: 'Môn học, nhiệm vụ và thời khóa biểu',
              toolbarHeight: 76,
              actions: [
                MochiIconButton(
                  tooltip: 'Thiết lập học tập cá nhân',
                  icon: Icons.tune_rounded,
                  onPressed: () => _setup(store),
                ),
              ],
            ),
            body: Column(
              children: [
                if (store.cloudService.hasActiveUser && !store.isCloudSynced)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MochiSpacing.md,
                      MochiSpacing.xs,
                      MochiSpacing.md,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MochiChip(
                        label:
                            'Thay đổi đang chờ đồng bộ hoặc cần kết nối lại.',
                        icon: Icons.cloud_sync_outlined,
                        tone: MochiChipTone.warning,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MochiSpacing.md,
                    MochiSpacing.sm,
                    MochiSpacing.md,
                    MochiSpacing.xs,
                  ),
                  child: AnimatedBuilder(
                    animation: tabs,
                    builder: (context, _) => MochiSegmentedControl<int>(
                      value: tabs.index,
                      segments: const [
                        MochiSegment(
                          value: 0,
                          label: 'Tiến độ môn',
                          icon: Icons.insights_outlined,
                        ),
                        MochiSegment(
                          value: 1,
                          label: 'Bài & lịch',
                          icon: Icons.event_note_outlined,
                        ),
                        MochiSegment(
                          value: 2,
                          label: 'Thời khóa biểu',
                          icon: Icons.calendar_view_week_outlined,
                        ),
                      ],
                      onChanged: tabs.animateTo,
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: tabs,
                    children: [
                      _responsiveTab(_progress(store)),
                      _responsiveTab(_agenda(store)),
                      _responsiveTab(_timetable(store)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _responsiveTab(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: child,
    ),
  );
}
