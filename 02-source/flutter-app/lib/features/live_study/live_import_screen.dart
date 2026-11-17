import '../../design/mochi_design.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../core/services/live_bridge_service.dart';
import '../../core/services/notification_service.dart';
import '../../shared/widgets/ai_message_body.dart';

class LiveImportScreen extends StatefulWidget {
  final LiveSessionImport session;
  const LiveImportScreen({super.key, required this.session});
  @override
  State<LiveImportScreen> createState() => _LiveImportScreenState();
}

class _LiveImportScreenState extends State<LiveImportScreen> {
  Map<String, dynamic>? _pack;
  String? _error;
  bool _loading = true;
  bool _saved = false;
  bool _saving = false;
  String? _reminderStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await LiveBridgeService.save(widget.session);
      if (!mounted) return;
      final pack = await context
          .read<MochiStore>()
          .aiService
          .studyPackFromTranscript(widget.session.text);
      if (mounted) setState(() => _pack = pack);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Đã giữ lời thoại trên máy nhưng chưa tạo được bản ôn tập. Bạn có thể thử lại.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCards() async {
    if (_pack == null || _saving) return;
    setState(() => _saving = true);
    final store = context.read<MochiStore>();
    // Stable ids make importing the same session idempotent.
    final deckId = 'live_${widget.session.id}';
    if (!store.decks.any((d) => d.id == deckId)) {
      store.decks.add(
        FlashcardDeck(
          id: deckId,
          title: _pack!['title'],
          subject: 'Trao đổi trực tiếp',
        ),
      );
      final cards = _pack!['cards'] as List;
      for (var i = 0; i < cards.length; i++) {
        store.flashcards.add(
          FlashcardItem(
            id: '${deckId}_$i',
            deckId: deckId,
            front: cards[i]['front'],
            back: cards[i]['back'],
          ),
        );
      }
    }
    try {
      await store.save();
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa lưu được thẻ. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remind() async {
    try {
      await NotificationService().scheduleLiveReview(
        widget.session.id,
        _pack!['reminder'],
      );
      if (mounted)
        setState(
          () => _reminderStatus = 'Đã đặt nhắc sau 24 giờ. Android có thể giao thông báo trễ khi tiết kiệm pin.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _reminderStatus =
              'Chưa đặt được thông báo. Kiểm tra quyền thông báo của MOCHI.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => MochiScaffold(
    appBar: MochiAppBar.detail(
      title: 'Nhập phiên học',
      subtitle: 'Tạo thẻ ôn tập từ nội dung đã ghi nhận',
    ),
    body: ListView(
      padding: const EdgeInsets.all(MochiSpacing.md),
      children: [
        MochiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phiên học trực tiếp',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.session.complete
                    ? 'Đã nhận lời thoại phiên vừa kết thúc.'
                    : 'Chỉ gồm phần lời thoại đã lấy được. Không bao gồm video hay toàn bộ nội dung đề trong ảnh.',
              ),
              const SizedBox(height: 8),
              const MochiNoticeBanner(
                message:
                    'Lịch sử đang lưu cục bộ trên thiết bị; chưa xác nhận đồng bộ đám mây.',
                severity: MochiNoticeSeverity.info,
                compact: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: MochiSpacing.sm),
        MochiCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            title: const Text('Xem lời thoại gốc'),
            children: [
              Padding(
                padding: const EdgeInsets.all(MochiSpacing.md),
                child: SelectableText(widget.session.text),
              ),
            ],
          ),
        ),
        if (_loading)
          const MochiCard(
            child: MochiLoadingState(
              label: 'Đang tạo bản ôn tập từ nội dung phiên…',
            ),
          ),
        if (_error != null) ...[
          MochiNoticeBanner(
            message: _error!,
            severity: MochiNoticeSeverity.error,
          ),
          MochiButton(
            label: 'Thử lại',
            icon: Icons.refresh_rounded,
            variant: MochiButtonVariant.secondary,
            onPressed: _loading ? null : _generate,
          ),
        ],
        if (_pack != null) ...[
          const SizedBox(height: MochiSpacing.md),
          Text(
            _pack!['title'],
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: MochiSpacing.xs),
          MochiCard(child: AIMessageBody(text: _pack!['summary'])),
          const SizedBox(height: MochiSpacing.md),
          Text(
            'Thẻ đề xuất — kiểm tra trước khi lưu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MochiSpacing.xs),
          for (final card in _pack!['cards'])
            MochiCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(MochiSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AIMessageBody(text: card['front']),
                    Divider(),
                    AIMessageBody(text: card['back']),
                  ],
                ),
              ),
            ),
          MochiButton(
            label: _saved
                ? 'Đã lưu vào Flashcard'
                : _saving
                ? 'Đang lưu…'
                : 'Lưu bộ thẻ',
            icon: Icons.style_outlined,
            loading: _saving,
            onPressed: _saved || _saving || (_pack!['cards'] as List).isEmpty
                ? null
                : _saveCards,
            expand: true,
          ),
          const SizedBox(height: MochiSpacing.sm),
          MochiNoticeBanner(
            message: _pack!['reminder'],
            severity: MochiNoticeSeverity.info,
            compact: true,
          ),
          MochiButton(
            label: 'Nhắc ôn lại sau 24 giờ',
            icon: Icons.notifications_active_outlined,
            variant: MochiButtonVariant.secondary,
            onPressed: _reminderStatus == null ? _remind : null,
          ),
          if (_reminderStatus != null)
            MochiNoticeBanner(
              message: _reminderStatus!,
              severity: MochiNoticeSeverity.info,
              compact: true,
            ),
        ],
      ],
    ),
  );
}
