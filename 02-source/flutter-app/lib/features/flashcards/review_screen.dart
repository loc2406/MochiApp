import 'package:mochi_app/design/foundation/mochi_tokens.dart';
import 'package:mochi_app/design/widgets/mochi_app_bar.dart';
import 'package:mochi_app/design/widgets/mochi_button.dart';
import 'package:mochi_app/design/widgets/mochi_card.dart';
import 'package:mochi_app/design/widgets/mochi_chip.dart';
import 'package:mochi_app/design/widgets/mochi_feedback.dart';
import 'package:mochi_app/design/widgets/mochi_list_tile.dart';
import 'package:mochi_app/design/widgets/mochi_notice_banner.dart';
import 'package:mochi_app/design/widgets/mochi_progress.dart';
import 'package:mochi_app/design/widgets/mochi_scaffold.dart';
import 'package:mochi_app/design/widgets/mochi_stat_tile.dart';

import '../../shared/widgets/floating_bar_inset.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../design/foundation/mochi_palette.dart';
import '../../design/pastel/pastel_components.dart';
import '../../core/learning/review_policy.dart';
import '../../core/learning/learning_models.dart';
import '../../shared/widgets/ai_message_body.dart';
import '../../shared/navigation/custom_page_transition.dart';
import '../robot/robot_mascot_widget.dart';
import 'review_quiz_card.dart';
import '../learning/learning_hub_screen.dart';
import 'flashcards_screen.dart';
import 'knowledge_explanation.dart';

/// A durable revision journey. The library is secondary, not the landing page.
class ReviewScreen extends StatelessWidget {
  final bool active;
  const ReviewScreen({super.key, required this.active});
  @override
  Widget build(BuildContext context) => _ReviewContent(active: active);
}

class _ReviewContent extends StatefulWidget {
  final bool active;
  const _ReviewContent({required this.active});
  @override
  State<_ReviewContent> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<_ReviewContent> {
  String? _owner, _sessionId, _error, _empty;
  String? _visibleCardId;
  bool _loading = false, _revealed = false, _saving = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner =
        context.watch<MochiStore>().cloudService.currentUserId ?? 'guest';
    if (_owner != owner) {
      _owner = owner;
      _sessionId = null;
      _loading = false;
      _error = null;
      _revealed = false;
      _saving = false;
      if (widget.active)
        WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
    }
  }

  @override
  void didUpdateWidget(covariant _ReviewContent old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active)
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare({bool offline = false}) async {
    if (!mounted || _loading || !widget.active) return;
    final store = context.read<MochiStore>(), owner = _owner;
    final now = DateTime.now(), date = MochiStore.dateKey(DateTime.now());
    final previous = store.learning.reviewSessions
        .where(
          (s) =>
              s['date'] == date &&
              (s['status'] == 'active' ||
                  (s['status'] == 'completed' && s['needsNewReview'] != true)),
        )
        .lastOrNull;
    if (previous != null) {
      setState(() => _sessionId = previous['id']);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _empty = null;
      _sessionId = null;
    });
    try {
      var cards = ReviewPolicy.dueCards(
        now: now,
        cards: store.flashcards,
        decks: store.decks,
        learning: store.learning,
      );
      final available = ReviewPolicy.availableMinutes(
        now: now,
        routine: store.dailyRoutine,
        learning: store.learning,
        tasks: store.tasks,
        sessions: store.sessions,
      );
      if (available < 2) {
        setState(
          () => _empty = 'Quỹ giờ học hôm nay đã kín. Không tự thêm việc ôn lấn lịch bận; bạn có thể chỉnh lịch sinh hoạt hoặc quản lý kiến thức.',
        );
        return;
      }
      if (cards.isEmpty) {
        LearningCourse? weakCourse;
        LearningTopic? weakTopic;
        final weaknesses =
            store.learning.progress
                .where((p) => p.readiness == TopicReadiness.needsReview)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        for (final progress in weaknesses) {
          if (store.decks.any((d) => d.topicIds.contains(progress.topicId)))
            continue;
          final course = store.learning.courses
              .where((c) => c.id == progress.courseId)
              .firstOrNull;
          final topic = course?.topics
              .where((t) => t.id == progress.topicId)
              .firstOrNull;
          if (course != null && topic != null) {
            weakCourse = course;
            weakTopic = topic;
            break;
          }
        }
        if (!offline &&
            store.cloudService.hasActiveUser &&
            weakTopic != null &&
            weakCourse != null) {
          final generated = await store.aiService.generateFlashcardsForTopic(
            topic:
                '${weakTopic.title} · Lớp ${store.learning.gradeLevel ?? store.profile.gradeBand}',
            subject: weakCourse.subject,
            count: 3,
          );
          if (!mounted || owner != _owner) return;
          // Only a topic explicitly marked for revision, never a guessed chapter.
          await store.addKnowledgePack(
            weakTopic.title,
            weakCourse.subject,
            [weakTopic.id],
            generated,
            operationKey: 'revision_${weakTopic.id}',
          );
          cards = ReviewPolicy.dueCards(
            now: DateTime.now(),
            cards: store.flashcards,
            decks: store.decks,
            learning: store.learning,
          );
        }
      }
      if (cards.isEmpty) {
        setState(
          () => _empty = 'Không có thẻ phù hợp đến hạn lúc này. Phần đã nhớ được giãn lịch; bạn không cần ôn lại chỉ để giữ chuỗi.',
        );
        return;
      }
      final sources = {
        for (final c in cards) c.id: [c.front, c.originalBack ?? c.back],
      };
      Map<String, dynamic> draft = {};
      var useOffline = offline || !store.cloudService.hasActiveUser;
      if (!useOffline) {
        try {
          draft = await store.aiService
              .prepareReview(
                cards: cards,
                decks: store.decks,
                budgetMinutes: available.clamp(2, 15),
                learningContext: {
                  'grade': store.learning.gradeLevel,
                  'progress': store.learning.progress
                      .map((p) => p.toJson())
                      .toList(),
                  'recentQuizResults': store.learning.reviewSessions.reversed
                      .take(3)
                      .map((s) => s['quiz'])
                      .toList(),
                },
              )
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          useOffline = true;
        }
      }
      if (!mounted || owner != _owner) return;
      if (!useOffline &&
          sources.entries.any((entry) {
            final current = store.flashcards
                .where((c) => c.id == entry.key)
                .firstOrNull;
            return current == null ||
                current.front != entry.value[0] ||
                (current.originalBack ?? current.back) != entry.value[1];
          })) {
        useOffline = true;
      }
      final id = await store.createReviewSession(draft, offline: useOffline);
      if (mounted && owner == _owner) setState(() => _sessionId = id);
    } catch (_) {
      if (mounted && owner == _owner)
        setState(
          () => _error = 'Chưa tạo được lượt ôn. Bạn có thể ôn thẻ đã lưu hoặc mở thư viện để thêm kiến thức.',
        );
    } finally {
      if (mounted && owner == _owner) setState(() => _loading = false);
    }
  }

  Future<void> _manage() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.push(
      context,
      CustomPageTransition.route<void>(
        context: context,
        builder: (_) => const FlashcardsScreen(),
      ),
    );
    if (mounted) {
      setState(() => _revealed = false);
      await _prepare();
    }
  }

  Future<void> _addSuggested(
    MochiStore store,
    LearningCourse course,
    LearningTopic topic,
  ) async {
    if (_loading) return;
    final owner = _owner;
    setState(() => _loading = true);
    try {
      final cards = await store.aiService.generateFlashcardsForTopic(
        topic:
            '${topic.title} · lớp ${store.learning.gradeLevel ?? store.profile.gradeBand}',
        subject: course.subject,
        count: 3,
      );
      if (!mounted || owner != _owner) return;
      // Single durable write, with an explicit topic link rather than guessing from a title.
      await store.addKnowledgePack(topic.title, course.subject, [
        topic.id,
      ], cards);
      if (mounted) {
        setState(() => _loading = false);
        await _prepare();
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Chưa tạo được nội dung cho chủ đề này. Hãy thử lại.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _suggestions(MochiStore store) {
    final suggestions = <(LearningCourse, LearningTopic)>[];
    for (final course in store.learning.courses) {
      for (final topic
          in course.topics
              .where(
                (t) =>
                    store.learning.readinessFor(t.id) ==
                    TopicReadiness.needsReview,
              )
              .take(3)) {
        suggestions.add((course, topic));
      }
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggestions.isNotEmpty) ...[
          MochiSection(
            title: 'Đề xuất từ tiến độ của bạn',
            children: [
              for (final (course, topic) in suggestions)
                MochiListTile(
                  title: topic.title,
                  subtitle: '${course.subject} · Bạn đã đánh dấu cần ôn',
                  leading: Icon(
                    Icons.auto_awesome_outlined,
                    size: MochiIconSize.md,
                    color: theme.colorScheme.primary,
                  ),
                  trailing: MochiIconButton(
                    icon: Icons.add,
                    tooltip: 'Tạo nội dung ôn ${topic.title}',
                    onPressed: _loading
                        ? null
                        : () => _addSuggested(store, course, topic),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MochiSpacing.sm),
        ],
        MochiSection(
          children: [
            MochiListTile(
              title: 'Cập nhật bài đang học và mức ghi nhớ',
              leading: Icon(
                Icons.school_outlined,
                size: MochiIconSize.md,
                color: theme.colorScheme.primary,
              ),
              onTap: () => Navigator.push(
                context,
                CustomPageTransition.route<void>(
                  context: context,
                  builder: (_) => const LearningHubScreen(),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MochiSpacing.sm,
            MochiSpacing.xs,
            MochiSpacing.sm,
            0,
          ),
          child: Text(
            'Dấu tiến độ là tự đánh giá. Nội dung AI mới cần được bạn kiểm tra, không phải đáp án đã xác minh.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Builder(builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final store = context.watch<MochiStore>();
    final session = store.learning.reviewSessions
        .where((s) => s['id'] == _sessionId)
        .firstOrNull;
    final Widget content;
    if (_loading) {
      content = const MochiCard(
        padding: EdgeInsets.zero,
        child: MochiLoadingState(
          label: 'Đang chọn kiến thức đến hạn và sắp lượt ôn vừa sức…',
        ),
      );
    } else if (session != null && session['status'] == 'completed') {
      content = _completedSession(store, session);
    } else if (session != null && session['status'] == 'active') {
      content = _activeSession(store, session);
    } else {
      content = _idleSession(store);
    }

    return MochiScaffold(
      appBar: MochiAppBar(
        title: 'Ôn tập',
        subtitle: 'Ôn vừa sức, nhớ lâu hơn.',
        large: true,
        actions: [
          MochiIconButton(
            icon: Icons.library_books_outlined,
            tooltip: 'Mở thư viện kiến thức',
            onPressed: _manage,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          MochiSpacing.xl,
          MochiSpacing.xs,
          MochiSpacing.xl,
          FloatingBarInset.of(context) + MochiSpacing.huge,
        ),
        children: [content],
      ),
    );
  }

  Widget _completedSession(MochiStore store, Map<String, dynamic> session) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final grades = (session['grades'] as Map?) ?? const {};
    final cardIds = List<String>.from(
      (session['cardIds'] as List?) ?? const [],
    );
    final quiz = (session['quiz'] as Map?) ?? const {};
    final questions = (quiz['questions'] as List?) ?? const [];
    final answers = (quiz['answers'] as Map?) ?? const {};
    final message = session['mode'] == 'offline'
        ? 'Lịch ôn đã cập nhật theo mức tự nhớ từ thẻ đã lưu.'
        : session['quizSkipped'] == true
        ? 'Đã lưu mức nhớ của thẻ và bỏ qua phần quiz còn lại. Các câu đã trả lời vẫn được giữ.'
        : 'Lịch ôn từng thẻ đã được cập nhật theo mức nhớ. Câu quiz sai được đưa về lượt ôn gần hơn, không tự đánh dấu đã vững.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MochiCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MochiProgressRing(
                value: 1,
                size: 56,
                strokeWidth: 6,
                icon: Icons.task_alt,
                semanticsLabel: 'Đã hoàn thành lượt ôn',
              ),
              const SizedBox(width: MochiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đã hoàn thành lượt ôn',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: MochiSpacing.xxs),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MochiSpacing.sm),
        MochiStatRow(
          children: [
            MochiStatTile(
              dense: true,
              label: 'Thẻ đã xếp lịch',
              value: '${grades.length}',
              unit: '/ ${cardIds.length}',
              icon: Icons.style_outlined,
            ),
            if (questions.isEmpty)
              const MochiStatTile(
                dense: true,
                label: 'Hình thức',
                value: 'Offline',
                caption: 'Không có quiz AI',
                icon: Icons.offline_bolt_outlined,
              )
            else
              MochiStatTile(
                dense: true,
                label: 'Câu quiz đã trả lời',
                value: '${answers.length}',
                unit: '/ ${questions.length}',
                icon: Icons.quiz_outlined,
              ),
          ],
        ),
        if (questions.isNotEmpty) ...[
          const SizedBox(height: MochiSpacing.sm),
          MochiCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: MochiSpacing.md,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  MochiSpacing.md,
                  0,
                  MochiSpacing.md,
                  MochiSpacing.md,
                ),
                title: Text(
                  'Xem kết quả và giải thích quiz',
                  style: theme.textTheme.titleSmall,
                ),
                children: [
                  for (final (index, q) in questions.indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: MochiSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MochiChip(
                            label: 'Câu ${index + 1}',
                            icon: Icons.help_outline,
                          ),
                          const SizedBox(height: MochiSpacing.xs),
                          AIMessageBody(
                            color: Theme.of(context).colorScheme.onSurface,
                            text: q['question'],
                          ),
                          Text(
                            'Đáp án AI (chưa xác minh): ${q['correctAnswer']}',
                          ),
                          AIMessageBody(
                            color: Theme.of(context).colorScheme.onSurface,
                            text: q['explanation'],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: MochiSpacing.md),
        MochiButton(
          label: 'Đến Quản lý kiến thức',
          icon: Icons.library_books_outlined,
          expand: true,
          onPressed: _manage,
        ),
        const SizedBox(height: MochiSpacing.lg),
        _suggestions(store),
      ],
    );
  }

  Widget _activeSession(MochiStore store, Map<String, dynamic> session) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ids = List<String>.from((session['cardIds'] as List?) ?? const []);
    final grades = (session['grades'] as Map?) ?? const {};
    final quiz = (session['quiz'] as Map?) ?? const {};
    final questions = (quiz['questions'] as List?) ?? const [];
    final answers = (quiz['answers'] as Map?) ?? const {};
    final offline = session['mode'] == 'offline';
    final pending = ids.where((id) => !grades.containsKey(id)).toList();
    final card = pending.isEmpty
        ? null
        : store.flashcards.where((c) => c.id == pending.first).firstOrNull;
    if (_visibleCardId != card?.id) {
      _visibleCardId = card?.id;
      _revealed = false;
    }
    final totalSteps = ids.length + (offline ? 0 : questions.length);
    final doneSteps = grades.length + (offline ? 0 : answers.length);
    final progress = totalSteps == 0
        ? 0.0
        : (doneSteps / totalSteps).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (offline) ...[
          const MochiNoticeBanner(
            message: 'Ôn offline · Dùng nội dung đã lưu, không có quiz AI.',
            severity: MochiNoticeSeverity.info,
            icon: Icons.offline_bolt_outlined,
            compact: true,
          ),
          const SizedBox(height: MochiSpacing.sm),
        ],
        if (store.syncError != null) ...[
          MochiNoticeBanner(
            message: store.syncError!,
            title: 'Chưa đồng bộ được',
            severity: MochiNoticeSeverity.warning,
            compact: true,
          ),
          const SizedBox(height: MochiSpacing.sm),
        ],
        MochiCard(
          child: Row(
            children: [
              MochiProgressRing(
                value: progress,
                size: 84,
                strokeWidth: 9,
                showValueLabel: false,
                semanticsLabel: 'Tiến độ lượt ôn',
                child: Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: MochiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lượt ôn hôm nay · khoảng ${session['durationMinutes']} phút',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: MochiSpacing.xs),
                    Wrap(
                      spacing: MochiSpacing.xs,
                      runSpacing: MochiSpacing.xs,
                      children: [
                        MochiChip(
                          label: 'Thẻ ${grades.length}/${ids.length}',
                          icon: Icons.style_outlined,
                        ),
                        if (!offline)
                          MochiChip(
                            label: 'Quiz ${answers.length}/${questions.length}',
                            icon: Icons.quiz_outlined,
                            tone: MochiChipTone.medium,
                          ),
                      ],
                    ),
                    const SizedBox(height: MochiSpacing.xs),
                    Text(
                      'Giờ ôn đã xếp: ${session['scheduledTime'] ?? 'Chưa có'} · ${session['scheduledDate'] ?? ''}. Bạn có thể chủ động ôn sớm.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MochiSpacing.sm),
        MochiCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: MochiSpacing.md,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                MochiSpacing.md,
                0,
                MochiSpacing.md,
                MochiSpacing.md,
              ),
              title: Text(
                'Vì sao có lượt ôn này?',
                style: theme.textTheme.titleSmall,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    session['reason'],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MochiSpacing.md),
        if (card != null) ...[
          MochiCard(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: MochiSpacing.md,
                    runSpacing: MochiSpacing.xs,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MochiChip(
                        label: _revealed ? 'Giải thích' : 'Mặt trước',
                        icon: _revealed
                            ? Icons.lightbulb_outline
                            : Icons.visibility_outlined,
                        tone: _revealed
                            ? MochiChipTone.medium
                            : MochiChipTone.accent,
                      ),
                      Text(
                        'Thẻ ${grades.length + 1}/${ids.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MochiSpacing.md),
                  if (_revealed)
                    KnowledgeExplanation(
                      color: Theme.of(context).colorScheme.onSurface,
                      text: card.back,
                    )
                  else
                    AIMessageBody(
                      color: Theme.of(context).colorScheme.onSurface,
                      text: card.front,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MochiSpacing.sm),
          if (!_revealed)
            MochiButton(
              label: _saving
                  ? 'Đang bổ sung giải thích dễ hiểu…'
                  : 'Xem giải thích',
              icon: Icons.lightbulb_outline,
              loading: _saving,
              expand: true,
              onPressed: _saving
                  ? null
                  : () async {
                      final owner = _owner;
                      setState(() {
                        _saving = true;
                        _revealed = true;
                        _error = null;
                      });
                      try {
                        if (session['mode'] != 'offline')
                          await store
                              .ensureKnowledgeExplanation(card.id)
                              .timeout(const Duration(seconds: 10));
                        if (mounted &&
                            owner == _owner &&
                            _visibleCardId == card.id)
                          setState(() => _revealed = true);
                      } catch (_) {
                        if (mounted && owner == _owner)
                          setState(
                            () => _error = 'AI chưa bổ sung được giải thích. Bạn vẫn có thể ôn với nội dung đã lưu ở trên.',
                          );
                      } finally {
                        if (mounted && owner == _owner)
                          setState(() => _saving = false);
                      }
                    },
            )
          else ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: MochiSpacing.xxs,
                bottom: MochiSpacing.xs,
              ),
              child: Text(
                'Bạn nhớ mức nào?',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            Wrap(
              spacing: MochiSpacing.xs,
              runSpacing: MochiSpacing.xs,
              children: [
                for (final entry in const {
                  0: 'Quên',
                  1: 'Còn khó',
                  2: 'Nhớ',
                  3: 'Rất chắc',
                }.entries)
                  MochiButton(
                    label: entry.value,
                    variant: MochiButtonVariant.secondary,
                    size: MochiButtonSize.small,
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            try {
                              await store.gradeReviewCard(
                                session['id'],
                                card.id,
                                entry.key,
                              );
                              if (mounted) setState(() => _revealed = false);
                            } catch (_) {
                              if (mounted)
                                setState(
                                  () => _error = 'Chưa ghi nhận được lượt ôn.',
                                );
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                  ),
              ],
            ),
          ],
        ] else if (pending.isNotEmpty) ...[
          MochiNoticeBanner(
            message: 'Thẻ đã thay đổi hoặc bị xóa. Mở quản lý kiến thức để kiểm tra.',
            severity: MochiNoticeSeverity.warning,
            actionLabel: 'Quản lý kiến thức',
            onAction: _manage,
          ),
        ] else ...[
          MochiNoticeBanner(
            message: 'Quiz do AI tạo · Đáp án chưa được xác minh. Hãy đối chiếu thẻ nguồn; kết quả không tự đánh dấu đã vững.',
            severity: MochiNoticeSeverity.info,
            icon: Icons.auto_awesome_outlined,
            compact: true,
          ),
          const SizedBox(height: MochiSpacing.sm),
          MochiCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: MochiSpacing.md,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  MochiSpacing.md,
                  0,
                  MochiSpacing.md,
                  MochiSpacing.sm,
                ),
                title: Text(
                  'Đối chiếu thẻ nguồn',
                  style: theme.textTheme.titleSmall,
                ),
                children: [
                  for (final c in store.flashcards.where(
                    (c) => ids.contains(c.id),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(top: MochiSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AIMessageBody(
                            color: Theme.of(context).colorScheme.onSurface,
                            text: c.front,
                          ),
                          const SizedBox(height: MochiSpacing.xs),
                          KnowledgeExplanation(
                            color: Theme.of(context).colorScheme.onSurface,
                            text: c.originalBack ?? c.back,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MochiSpacing.sm),
          MochiButton(
            label: 'Bỏ qua quiz chưa xác minh',
            icon: Icons.skip_next_outlined,
            variant: MochiButtonVariant.secondary,
            expand: true,
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await store.skipReviewQuiz(session['id']);
                    } catch (_) {
                      if (mounted)
                        setState(
                          () => _error = 'Chưa bỏ qua được quiz. Hãy kiểm tra lại lượt ôn.',
                        );
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
          ),
          const SizedBox(height: MochiSpacing.lg),
          Text('Kiểm tra khả năng vận dụng', style: theme.textTheme.titleLarge),
          const SizedBox(height: MochiSpacing.sm),
          ReviewQuizCard(
            key: ValueKey(session['id']),
            data: Map<String, dynamic>.from(session['quiz']),
            onAnswer: (q, o) => store.answerReviewQuiz(session['id'], q, o),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: MochiSpacing.sm),
          MochiNoticeBanner(
            message: _error!,
            severity: MochiNoticeSeverity.error,
            compact: true,
          ),
        ],
      ],
    );
  }

  Widget _idleSession(MochiStore store) {
    final message =
        _error ??
        _empty ??
        (_sessionId != null
            ? 'Lượt ôn đã thay đổi trên thiết bị khác. Hãy tạo lượt ôn mới.'
            : 'Đang đọc tiến độ ôn tập…');
    final title = _error != null
        ? 'Chưa sắp được lượt ôn'
        : _empty != null
        ? 'Chưa có lượt ôn mới'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Mochi đang chờ bạn ôn tập',
          image: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: RadialGradient(
                colors: [
                  MochiPalette.of(context).softAccent,
                  MochiPalette.of(context).softAccent.withValues(alpha: 0),
                ],
              ),
            ),
            child: RobotMascotWidget(
              size: 132,
              primaryColor: MochiPalette.of(context).accent,
            ),
          ),
        ),
        const SizedBox(height: MochiSpacing.sm),
        Text(
          'Một chút ôn tập, nhớ thêm mỗi ngày',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: MochiSpacing.md),
        const SizedBox(height: MochiSpacing.xs),
        MochiNoticeBanner(
          message: message,
          title: title,
          severity: _error != null
              ? MochiNoticeSeverity.error
              : MochiNoticeSeverity.info,
          icon: _error != null
              ? Icons.cloud_off_outlined
              : Icons.event_available_outlined,
          actionLabel: _error != null ? 'Thử sắp lượt ôn lại' : null,
          onAction: _error != null ? _prepare : null,
        ),
        const SizedBox(height: MochiSpacing.sm),
        if (!_loading) ...[
          MochiButton(
            label: 'Ôn thẻ đã lưu (offline)',
            icon: Icons.offline_bolt_outlined,
            expand: true,
            onPressed: () => _prepare(offline: true),
          ),
          const SizedBox(height: MochiSpacing.sm),
        ],
        MochiButton(
          label: 'Quản lý kiến thức',
          icon: Icons.library_books_outlined,
          variant: MochiButtonVariant.secondary,
          expand: true,
          onPressed: _manage,
        ),
        const SizedBox(height: MochiSpacing.lg),
        _suggestions(store),
      ],
    );
  }
}
