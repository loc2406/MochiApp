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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Nhập phiên học')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text('Phiên học trực tiếp'),
        SizedBox(height: 8),
        Text(
          widget.session.complete ? 'Đã nhận lời thoại phiên vừa kết thúc.' : 'Chỉ gồm phần lời thoại đã lấy được. Không bao gồm video hay toàn bộ nội dung đề trong ảnh.',
        ),
        Text(
          'Lịch sử đang lưu cục bộ trên thiết bị; chưa xác nhận đồng bộ đám mây.',
        ),
        ExpansionTile(
          title: Text('Xem lời thoại gốc'),
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: SelectableText(widget.session.text),
            ),
          ],
        ),
        if (_loading)
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Đang tạo bản ôn tập từ nội dung phiên…'),
              ],
            ),
          ),
        if (_error != null) ...[
          Text(_error!),
          TextButton(
            onPressed: _loading ? null : _generate,
            child: Text('Thử lại'),
          ),
        ],
        if (_pack != null) ...[
          SizedBox(height: 16),
          Text(_pack!['title'], style: Theme.of(context).textTheme.titleLarge),
          AIMessageBody(text: _pack!['summary']),
          SizedBox(height: 16),
          Text('Thẻ đề xuất — kiểm tra trước khi lưu'),
          for (final card in _pack!['cards'])
            MochiCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(14),
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
          MochiPrimaryButton(
            onPressed: _saved || _saving || (_pack!['cards'] as List).isEmpty
                ? null
                : _saveCards,
            child: Text(
              _saved
                  ? 'Đã lưu vào Flashcard'
                  : _saving
                  ? 'Đang lưu…'
                  : 'Lưu bộ thẻ',
            ),
          ),
          SizedBox(height: 12),
          AIMessageBody(text: _pack!['reminder']),
          OutlinedButton(
            onPressed: _reminderStatus == null ? _remind : null,
            child: Text('Nhắc ôn lại sau 24 giờ'),
          ),
          if (_reminderStatus != null) Text(_reminderStatus!),
        ],
      ],
    ),
  );
}
