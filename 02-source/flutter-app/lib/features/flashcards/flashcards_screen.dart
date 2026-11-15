import '../../shared/widgets/ai_message_body.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../design/mochi_design.dart';
import '../../shared/widgets/mochi_icons.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  String? _selectedDeckId;
  String _query = '';
  String? _subject;
  bool _dueOnly = false;

  bool _matches(FlashcardItem card, MochiStore store) {
    final deck = store.decks.where((d) => d.id == card.deckId).firstOrNull;
    final text =
        '${card.front} ${card.back} ${deck?.title ?? ''} ${deck?.subject ?? ''}'
            .toLowerCase();
    return (_query.trim().isEmpty ||
            text.contains(_query.trim().toLowerCase())) &&
        (_subject == null || deck?.subject == _subject) &&
        (!_dueOnly || !card.nextReviewAt.isAfter(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) => Builder(builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final store = context.watch<MochiStore>();

    if (_selectedDeckId != null) return _deckDetail(context, store);

    return MochiScaffold(
      appBar: MochiAppBar(
        title: 'Quản lý kiến thức',
        subtitle: 'Thẻ và bộ thẻ của bạn, dùng được cả khi offline.',
        large: true,
        actions: [
          MochiIconButton(
            icon: Icons.auto_awesome,
            tooltip: 'AI tạo bộ thẻ tự động',
            onPressed: () => _showAIGenerateDialog(context, store),
          ),
          MochiIconButton(
            icon: Icons.add_box_outlined,
            tooltip: 'Tạo bộ thẻ mới',
            onPressed: () => _showAddDeckDialog(context, store),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          MochiSpacing.xl,
          MochiSpacing.xs,
          MochiSpacing.xl,
          MochiSpacing.xxl,
        ),
        children: [
          MochiSearchField(
            label: 'Tìm thẻ hoặc bộ thẻ',
            hint: 'Nhập từ khoá…',
            onChanged: (value) => setState(() => _query = value),
          ),
          SizedBox(height: MochiSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _subject,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Môn học'),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('Tất cả môn học'),
              ),
              for (final subject
                  in (store.decks.map((d) => d.subject).toSet().toList()
                    ..sort()))
                DropdownMenuItem(value: subject, child: Text(subject)),
            ],
            onChanged: (value) => setState(() => _subject = value),
          ),
          SizedBox(height: MochiSpacing.sm),
          Wrap(
            spacing: MochiSpacing.xs,
            runSpacing: MochiSpacing.xs,
            children: [
              MochiFilterChip(
                label: 'Đến hạn ôn',
                icon: Icons.schedule_rounded,
                selected: _dueOnly,
                onSelected: (value) => setState(() => _dueOnly = value),
              ),
            ],
          ),
          SizedBox(height: MochiSpacing.md),
          if (store.decks.isEmpty)
            _emptyLibrary(context, store)
          else if (_query.trim().isNotEmpty || _subject != null || _dueOnly)
            ..._searchResults(context, store)
          else
            ..._deckList(context, store),
        ],
      ),
    );
  }

  List<Widget> _searchResults(BuildContext context, MochiStore store) {
    final palette = MochiPalette.of(context);
    final matching = store.flashcards.where((c) => _matches(c, store)).toList();
    return [
      MochiChip(
        label: '${matching.length} thẻ phù hợp',
        tone: matching.isEmpty ? MochiChipTone.neutral : MochiChipTone.accent,
      ),
      SizedBox(height: MochiSpacing.sm),
      if (matching.isEmpty)
        MochiNoticeBanner(
          message: 'Không tìm thấy thẻ. Hãy đổi từ khóa hoặc bộ lọc.',
          severity: MochiNoticeSeverity.info,
          icon: Icons.search_off_rounded,
        ),
      for (final card in matching)
        Padding(
          padding: EdgeInsets.only(bottom: MochiSpacing.sm),
          child: MochiCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: Border(),
                collapsedShape: Border(),
                title: Text(
                  card.front,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  store.decks
                          .where((d) => d.id == card.deckId)
                          .firstOrNull
                          ?.title ??
                      'Bộ thẻ',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.muted),
                ),
                childrenPadding: EdgeInsets.fromLTRB(
                  MochiSpacing.lg,
                  0,
                  MochiSpacing.lg,
                  MochiSpacing.sm,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AIMessageBody(text: card.back),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showEditKnowledge(context, store, card),
                      icon: Icon(Icons.edit_outlined, size: 18),
                      label: Text('Sửa kiến thức này'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _deckList(BuildContext context, MochiStore store) {
    return [
      for (final deck in store.decks)
        Padding(
          padding: EdgeInsets.only(bottom: MochiSpacing.sm),
          child: MochiCard(
            padding: EdgeInsets.zero,
            onTap: () => setState(() => _selectedDeckId = deck.id),
            child: MochiListTile(
              title: deck.title,
              subtitle:
                  '${deck.subject} · ${store.flashcards.where((c) => c.deckId == deck.id).length} thẻ · '
                  '${store.flashcards.where((c) => c.deckId == deck.id && !c.nextReviewAt.isAfter(DateTime.now())).length} đến hạn',
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MochiPalette.of(context).softAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: MochiVectorIcon(
                    'flashcard',
                    size: 22,
                    color: MochiPalette.of(context).accent,
                  ),
                ),
              ),
              showChevron: true,
            ),
          ),
        ),
    ];
  }

  Widget _emptyLibrary(BuildContext context, MochiStore store) => MochiCard(
    child: MochiEmptyState(
      asset: 'assets/images/robot_idle.png',
      title: 'Chưa có bộ thẻ nào',
      message: 'Chưa có bộ thẻ. Tạo và lưu kiến thức để ôn cả khi offline.',
      actionLabel: 'Tự tạo bộ thẻ',
      onAction: () => _showAddDeckDialog(context, store),
    ),
  );

  Widget _deckDetail(BuildContext context, MochiStore store) {
    final deck = store.decks.firstWhere(
      (d) => d.id == _selectedDeckId,
      orElse: () => FlashcardDeck(id: '', title: '', subject: ''),
    );
    final cards = store.flashcards
        .where((c) => c.deckId == _selectedDeckId)
        .toList();
    final palette = MochiPalette.of(context);

    return MochiScaffold(
      appBar: MochiAppBar.detail(
        title: deck.title,
        subtitle: '${deck.subject} · ${cards.length} thẻ',
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => setState(() => _selectedDeckId = null),
          style: IconButton.styleFrom(
            foregroundColor: palette.ink,
            minimumSize: Size(MochiSpacing.touch, MochiSpacing.touch),
          ),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        actions: [
          MochiIconButton(
            icon: Icons.add,
            tooltip: 'Thêm thẻ mới',
            onPressed: () => _showAddCardDialog(context, store, deck.id),
          ),
        ],
      ),
      body: cards.isEmpty
          ? Padding(
              padding: EdgeInsets.all(MochiSpacing.lg),
              child: MochiCard(
                child: MochiEmptyState(
                  asset: 'assets/images/robot_idle.png',
                  title: 'Bộ thẻ này chưa có thẻ nào',
                  message: 'Thêm thẻ đầu tiên để bắt đầu xây dựng kiến thức cho bộ thẻ này.',
                  actionLabel: 'Thêm thẻ đầu tiên',
                  onAction: () => _showAddCardDialog(context, store, deck.id),
                ),
              ),
            )
          : _CardReviewSwiper(
              cards: cards,
              onEdit: (card) => _showEditKnowledge(context, store, card),
              onReview: (cardId, grade) {
                HapticFeedback.lightImpact();
                store.reviewFlashcard(cardId, grade);
              },
            ),
    );
  }

  Future<void> _showEditKnowledge(
    BuildContext context,
    MochiStore store,
    FlashcardItem card,
  ) async {
    final front = TextEditingController(text: card.front),
        back = TextEditingController(text: card.back);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Sửa kiến thức cần ôn'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MochiTextField(
                    controller: front,
                    label: 'Câu hỏi / kiến thức',
                    minLines: 2,
                    maxLines: 5,
                  ),
                  SizedBox(height: MochiSpacing.sm),
                  MochiTextField(
                    controller: back,
                    label: 'Giải thích, công thức và ví dụ',
                    minLines: 3,
                    maxLines: 10,
                  ),
                  SizedBox(height: MochiSpacing.xs),
                  Text(
                    'Sửa nội dung sẽ đưa thẻ về lịch ôn gần nhất. Lượt ôn đang dùng thẻ cũ sẽ được tạo lại.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  if (error != null) ...[
                    SizedBox(height: MochiSpacing.xs),
                    MochiNoticeBanner(
                      message: error!,
                      severity: MochiNoticeSeverity.error,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
            MochiPrimaryButton(
              onPressed: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                try {
                  await store.editKnowledgeCard(card.id, front.text, back.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  if (ctx.mounted)
                    update(() => error = 'Nhập đủ câu hỏi và giải thích.');
                }
              },
              child: Text('Lưu kiến thức'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(Duration(milliseconds: 300));
    front.dispose();
    back.dispose();
  }

  void _showAIGenerateDialog(BuildContext context, MochiStore store) {
    final topicCtrl = TextEditingController();
    String selectedSubj = 'Toán';
    final palette = MochiPalette.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: palette.accent, size: 22),
            SizedBox(width: MochiSpacing.xs),
            Expanded(child: Text('Mochi AI tạo thẻ')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nhập chủ đề học tập để AI tạo câu hỏi và đáp án ôn tập tự động:',
                style: Theme.of(ctx).textTheme.bodySmall
                    ?.copyWith(color: palette.muted),
              ),
              SizedBox(height: MochiSpacing.sm),
              MochiTextField(
                controller: topicCtrl,
                hint: 'Ví dụ: Định luật Newton, Thì quá khứ đơn...',
              ),
              SizedBox(height: MochiSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: selectedSubj,
                items:
                    [
                          'Toán',
                          'Vật lý',
                          'Hóa học',
                          'Tiếng Anh',
                          'Ngữ văn',
                          'Tin học',
                          'Sinh học',
                          'Chung',
                        ]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (v) {
                  if (v != null) selectedSubj = v;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
          MochiPrimaryButton(
            onPressed: () async {
              final topic = topicCtrl.text.trim();
              if (topic.isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Mochi AI đang chuẩn bị các câu hỏi ôn tập...',
                    ),
                  ),
                );
                final cards = await store.aiService.generateFlashcardsForTopic(
                  topic: topic,
                  subject: selectedSubj,
                );
                final deckId = store.addDeck(topic, selectedSubj);
                for (final c in cards) {
                  store.addFlashcard(deckId, c['front'] ?? '', c['back'] ?? '');
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Đã tạo thành công bộ thẻ: $topic (${cards.length} thẻ)!',
                      ),
                    ),
                  );
                }
              }
            },
            child: Text('Tạo với AI'),
          ),
        ],
      ),
    );
  }

  void _showAddDeckDialog(BuildContext context, MochiStore store) {
    final titleCtrl = TextEditingController();
    String subject = 'Toán';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tạo bộ Flashcard mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MochiTextField(controller: titleCtrl, hint: 'Tên bộ thẻ'),
              SizedBox(height: MochiSpacing.sm),
              MochiTextField(hint: 'Môn học', onChanged: (v) => subject = v),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
          MochiPrimaryButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                store.addDeck(titleCtrl.text.trim(), subject);
                Navigator.pop(ctx);
              }
            },
            child: Text('Tạo'),
          ),
        ],
      ),
    );
  }

  void _showAddCardDialog(
    BuildContext context,
    MochiStore store,
    String deckId,
  ) {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm Flashcard'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MochiTextField(
                controller: frontCtrl,
                hint: 'Mặt trước (Câu hỏi / Từ khóa)',
                maxLines: 2,
              ),
              SizedBox(height: MochiSpacing.sm),
              MochiTextField(
                controller: backCtrl,
                hint: 'Mặt sau (Đáp án / Giải thích)',
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
          MochiPrimaryButton(
            onPressed: () {
              if (frontCtrl.text.trim().isNotEmpty &&
                  backCtrl.text.trim().isNotEmpty) {
                store.addFlashcard(
                  deckId,
                  frontCtrl.text.trim(),
                  backCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              }
            },
            child: Text('Thêm thẻ'),
          ),
        ],
      ),
    );
  }
}

class _CardReviewSwiper extends StatefulWidget {
  final List<FlashcardItem> cards;
  final void Function(FlashcardItem) onEdit;
  final Function(String cardId, int grade) onReview;

  const _CardReviewSwiper({
    required this.cards,
    required this.onReview,
    required this.onEdit,
  });

  @override
  State<_CardReviewSwiper> createState() => _CardReviewSwiperState();
}

class _CardReviewSwiperState extends State<_CardReviewSwiper> {
  int _currentIndex = 0;
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);

    if (_currentIndex >= widget.cards.length) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(MochiSpacing.lg),
        child: MochiCard(
          child: MochiEmptyState(
            asset: 'assets/images/robot_celebrate.png',
            title: 'Hoàn thành phiên ôn tập!',
            message: 'Bạn đã xem lại hết tất cả thẻ trong lượt này.',
            actionLabel: 'Ôn lại từ đầu',
            onAction: () => setState(() {
              _currentIndex = 0;
              _showAnswer = false;
            }),
          ),
        ),
      );
    }

    final card = widget.cards[_currentIndex];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MochiSpacing.xl,
        MochiSpacing.sm,
        MochiSpacing.xl,
        MochiSpacing.xxl,
      ),
      child: Column(
        children: [
          MochiProgressBar(
            value: (_currentIndex + 1) / widget.cards.length,
            label: 'Thẻ ${_currentIndex + 1} / ${widget.cards.length}',
            showValue: false,
          ),
          SizedBox(height: MochiSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => widget.onEdit(card),
              icon: Icon(Icons.edit_outlined, size: 18),
              label: Text('Sửa kiến thức này'),
            ),
          ),
          SizedBox(height: MochiSpacing.xs),
          SizedBox(
            height: 360,
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: MochiCard(
                padding: EdgeInsets.zero,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(MochiSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MochiChip(
                        label: _showAnswer
                            ? 'MẶT SAU (ĐÁP ÁN)'
                            : 'MẶT TRƯỚC (CÂU HỎI)',
                        tone: _showAnswer
                            ? MochiChipTone.medium
                            : MochiChipTone.accent,
                        compact: true,
                      ),
                      SizedBox(height: MochiSpacing.md),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            child: AIMessageBody(
                              text: _showAnswer ? card.back : card.front,
                              color: palette.ink,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: MochiSpacing.md),
                      Text(
                        _showAnswer
                            ? 'Chạm để xem câu hỏi'
                            : 'Chạm để xem đáp án',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MochiSpacing.md),
          if (_showAnswer)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: MochiSpacing.xs,
              runSpacing: MochiSpacing.xs,
              children: [
                _buildGradeBtn('Quên', 0, MochiButtonVariant.danger),
                _buildGradeBtn('Khó', 1, MochiButtonVariant.secondary),
                _buildGradeBtn('Nhớ tốt', 2, MochiButtonVariant.secondary),
                _buildGradeBtn('Dễ', 3, MochiButtonVariant.primary),
              ],
            )
          else
            MochiButton(
              label: 'Xem đáp án',
              icon: Icons.visibility_outlined,
              expand: true,
              onPressed: () => setState(() => _showAnswer = true),
            ),
        ],
      ),
    );
  }

  Widget _buildGradeBtn(String label, int grade, MochiButtonVariant variant) {
    return MochiButton(
      label: label,
      size: MochiButtonSize.small,
      variant: variant,
      onPressed: () {
        widget.onReview(widget.cards[_currentIndex].id, grade);
        setState(() {
          _currentIndex++;
          _showAnswer = false;
        });
      },
    );
  }
}
