import '../../design/mochi_design.dart';

import '../../shared/widgets/floating_bar_inset.dart';

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import 'dart:async';

import 'widgets/tutor_quiz_card.dart';
import 'widgets/schedule_change_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../core/services/ai_service.dart';
import '../robot/robot_mascot_widget.dart';
import '../../shared/widgets/ai_message_body.dart';

class AITutorScreen extends StatefulWidget {
  final TaskModel? taskContext;
  final bool inSheet;

  /// Chuyển sang mục Tôi để đăng nhập. Null khi màn hình mở dạng sheet từ
  /// phiên học (không có thanh tab để chuyển).
  final VoidCallback? onRequestLogin;

  const AITutorScreen({
    super.key,
    this.taskContext,
    this.inSheet = false,
    this.onRequestLogin,
  });

  @override
  State<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends State<AITutorScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  String _conversationOwner = '__initial__';

  /// Tăng mỗi lần gửi/huỷ để bỏ qua phản hồi về muộn sau khi đã huỷ.
  int _requestSerial = 0;
  XFile? _attachedImage;
  String? _attachedImageBase64;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.watch<MochiStore>();
    final owner = store.cloudService.currentUserId ?? 'guest';
    if (_conversationOwner != owner) {
      _conversationOwner = owner;
      _isLoading = false;
      _msgController.clear();
      _messages.removeWhere((m) => m.id != 'welcome');
      _messages.addAll(store.tutorMessages);
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  final List<String> _quickPrompts = [
    'Giải thích định luật vạn vật hấp dẫn',
    'Cách phân biệt thì Hiện tại hoàn thành và Quá khứ đơn',
    'Phương pháp giải phương trình bậc hai nhanh nhất',
    'Cách lập dàn ý bài văn nghị luận xã hội',
  ];

  @override
  void initState() {
    super.initState();
    final contextInfo = widget.taskContext != null
        ? 'Bạn đang trong bài học: "${widget.taskContext!.title}" môn ${widget.taskContext!.subject}. '
        : '';
    _messages.add(
      ChatMessageModel(
        id: 'welcome',
        role: 'assistant',
        content:
            '${contextInfo}Bạn muốn cùng mình gỡ bài nào hôm nay? Gửi đề bài hoặc chỗ bạn chưa hiểu nhé.',
      ),
    );
  }

  void _sendMessage([String? prefilled]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final text = (prefilled ?? _msgController.text).trim();
    final imgBase64 = _attachedImageBase64;
    if ((text.isEmpty && imgBase64 == null) || _isLoading) return;

    HapticFeedback.lightImpact();
    if (prefilled == null) {
      _msgController.clear();
    }
    final displayContent = imgBase64 != null
        ? (text.isNotEmpty
              ? '[Đính kèm ảnh đề bài] ' + text
              : '[Đính kèm ảnh đề bài]')
        : text;
    final userMsg = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: displayContent,
    );

    setState(() {
      _attachedImage = null;
      _attachedImageBase64 = null;
      _messages.add(userMsg);
      _isLoading = true;
    });

    _scrollToBottom();

    final store = context.read<MochiStore>();
    unawaited(store.recordTutorMessage(userMsg));
    if (!mounted) return;
    final requestOwner = _conversationOwner;
    final serial = ++_requestSerial;
    store.setRobotEmotion(RobotEmotion.thinking);

    Map<String, dynamic>? detectedQuiz;
    String? quizError;
    Map<String, dynamic>? detectedAction;
    String? actionReply;
    bool actionFailed = false;

    if (imgBase64 != null) {
      try {
        final visionRes = await store.aiService.solveProblemWithImage(
          imageDataUri: imgBase64,
          userQuestion: text,
          subject: widget.taskContext?.subject ?? 'Toán',
          gradeBand: store.learning.gradeLevel == null
              ? store.profile.gradeBand
              : '${store.profile.gradeBand} · Lớp ${store.learning.gradeLevel}',
          learnerName: store.profile.name,
          companionName: store.profile.robotName,
        );
        actionReply =
            visionRes['reply']?.toString() ?? 'Chưa đọc được nội dung từ ảnh.';
      } catch (e) {
        actionFailed = true;
        actionReply = 'Chưa phân tích được ảnh đề bài lúc này. Bạn thử chụp rõ nét hơn hoặc gửi lại nhé.';
      }
    }

    final lower = text.toLowerCase();
    if (imgBase64 == null &&
        (lower.contains('quiz') ||
            lower.contains('trắc nghiệm') ||
            lower.contains('kiểm tra'))) {
      try {
        final topic =
            '$text · Bài đang học: ${widget.taskContext?.title ?? 'Chưa chọn'} · Lớp ${store.learning.gradeLevel ?? store.profile.gradeBand}';
        detectedQuiz = await store.aiService.generateQuiz(
          topic: topic,
          subject: widget.taskContext?.subject ?? 'Theo yêu cầu người học',
          count: 3,
        );
      } catch (_) {
        quizError = 'Chưa tạo được quiz hợp lệ. Bạn thử lại nhé; chưa có kết quả nào được lưu.';
      }
    } else if (lower.contains('dời') ||
        lower.contains('doi ') ||
        lower.contains('hoãn') ||
        lower.contains('hoan ') ||
        lower.contains('bận') ||
        lower.contains('sửa lịch')) {
      try {
        final result = await store.aiService.proposeScheduleChange(
          message: text,
          tasks: store.tasks,
          now: DateTime.now(),
        );
        if (result['action'] == 'clarify') {
          actionReply = result['question'];
        } else {
          detectedAction = {
            ...result,
            'ownerId': store.cloudService.currentUserId ?? 'guest',
            'status': 'proposed',
          };
          actionReply = 'Mình đã chuẩn bị đề xuất bên dưới. Kiểm tra đúng nhiệm vụ và giờ mới rồi xác nhận nhé; lịch chưa thay đổi.';
        }
      } catch (_) {
        actionFailed = true;
        actionReply = 'Chưa phân tích được yêu cầu dời lịch. Bạn thử lại nhé; chưa có lịch nào thay đổi.';
      }
    }

    if (!mounted || serial != _requestSerial) return;

    final res = detectedQuiz != null
        ? <String, dynamic>{
            'reply': 'Mình cùng thử từng câu nhé. Chọn đáp án trước khi xem giải thích.',
            'source': 'groq_cloud',
            'emotion': RobotEmotion.happy,
          }
        : quizError != null
        ? <String, dynamic>{
            'reply': quizError,
            'source': 'unavailable',
            'reason': 'unknown',
          }
        : actionReply != null
        ? <String, dynamic>{
            'reply': actionReply,
            'source': actionFailed ? 'unavailable' : 'groq_cloud',
            if (actionFailed) 'reason': 'unknown',
          }
        : await store.aiService.askTutor(
            question: text,
            subject: widget.taskContext?.subject ?? 'Chung',
            currentTaskTitle: widget.taskContext?.title ?? 'Tự học',
            gradeBand: store.learning.gradeLevel == null
                ? store.profile.gradeBand
                : '${store.profile.gradeBand} · Lớp ${store.learning.gradeLevel}',
            academicContext: {
              'schoolYear': store.learning.academicYear,
              'courses': store.learning.courses.map((c) => c.toJson()).toList(),
              'selfReportedProgress': store.learning.progress
                  .map((p) => p.toJson())
                  .toList(),
              'pendingTasks': store.tasks
                  .where((t) => !t.isDone)
                  .take(20)
                  .map((t) => t.toJson())
                  .toList(),
            },
            history: _messages,
            learnerName: store.profile.name,
            companionName: store.profile.robotName,
            learningGoal: store.profile.mainGoal,
            persona: store.profile.tutorPersona,
            detailLevel: store.profile.tutorDetailLevel,
          );

    if (!mounted ||
        requestOwner != _conversationOwner ||
        serial != _requestSerial)
      return;

    final botReply = res['reply'] ?? 'Mochi đang lắng nghe bạn...';
    final emotion = res['emotion'] as RobotEmotion? ?? RobotEmotion.happy;

    setState(() {
      _messages.add(
        ChatMessageModel(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          role: 'assistant',
          content: botReply,
          suggestedEmotion: emotion,
          source: res['source'] as String?,
          truncated: res['truncated'] == true,
          model: res['model'] as String?,
          requestId: res['requestId'] as String?,
          failureReason: res['reason'] as String?,
          quizData: detectedQuiz,
          scheduleActionData: detectedAction,
        ),
      );
      _isLoading = false;
    });

    unawaited(store.recordTutorMessage(_messages.last));
    store.setRobotEmotion(emotion);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Bỏ chờ phản hồi. Request HTTP vẫn chạy tới cùng nhưng kết quả về muộn
  /// bị bỏ qua nhờ `_requestSerial`.
  void _cancelRequest() {
    if (!_isLoading) return;
    HapticFeedback.selectionClick();
    _requestSerial++;
    setState(() => _isLoading = false);
    context.read<MochiStore>().setRobotEmotion(RobotEmotion.idle);
  }

  void _requestLogin() {
    final onRequestLogin = widget.onRequestLogin;
    if (onRequestLogin != null) {
      onRequestLogin();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đóng phiên học rồi vào mục Tôi để đăng nhập nhé.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    // Scaffold bên trong co giãn body theo bàn phím rồi xoá viewInsets khỏi
    // context con, nên phải đọc inset ở đây để không cộng đôi khoảng chừa.
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: widget.inSheet,
        toolbarHeight: 64 * MediaQuery.textScalerOf(context).scale(1),
        titleSpacing: 16,
        title: Row(
          children: [
            RobotMascotWidget(
              size: 34,
              emotion: store.robotEmotion,
              primaryColor: Color(store.robotColorHex),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Học cùng ${store.profile.robotName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: MochiPalette.of(context).ink,
                    ),
                  ),
                  Text(
                    'Cùng hiểu bài, từng chút một',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: MochiPalette.of(context).muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final barInset = FloatingBarInset.of(context);
          final keyboardOpen = keyboardInset > 0;
          final effectiveBottom = widget.inSheet
              ? (keyboardOpen ? keyboardInset + 8.0 : safeBottom + 8.0)
              : (keyboardOpen
                    ? keyboardInset + 8.0
                    : (barInset > 0 ? barInset + 4.0 : safeBottom + 8.0));
          // Cùng một bề rộng nội dung cho danh sách, chip gợi ý và ô soạn tin.
          final horizontal = constraints.maxWidth >= 760
              ? (constraints.maxWidth - 720) / 2
              : 16.0;
          final composerPaddingBottom =
              (_attachedImage != null ? 108.0 : 68.0) + effectiveBottom;
          final accent = MochiPresets.accentFor(store.profile.themePreset);
          final isHighContrast = store.profile.highContrast;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Layer 0: Full height scrollable messages list with no dead background blocks
              Positioned.fill(
                child: ListView.builder(
                  key: ValueKey('tutor_messages_list'),
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    constraints.maxHeight > 300 ? 56 : 16,
                    horizontal,
                    composerPaddingBottom,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg.role == 'user';

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth > 800
                              ? 720
                              : constraints.maxWidth * 0.94,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? MochiPalette.of(context).accent
                              : MochiPalette.of(context).card,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(isUser ? 18 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 18),
                          ),
                          border: Border.all(
                            color: isUser
                                ? Colors.transparent
                                : MochiPalette.of(context).cardBorder,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MochiPalette.of(context).ink
                                  .withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUser)
                              SelectableText(
                                msg.content,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: MochiPalette.of(context).onAccent,
                                ),
                              )
                            else ...[
                              AIMessageBody(text: msg.content),
                              if (msg.quizData != null)
                                TutorQuizCard(
                                  key: ValueKey('quiz-' + msg.id),
                                  data: msg.quizData!,
                                  onAnswer: (question, option) async {
                                    await store.answerTutorQuiz(
                                      msg.id,
                                      question,
                                      option,
                                    );
                                    if (!mounted) return;
                                    final updated = store.tutorMessages
                                        .firstWhere((m) => m.id == msg.id);
                                    setState(() {
                                      final index = _messages.indexWhere(
                                        (m) => m.id == msg.id,
                                      );
                                      if (index != -1) {
                                        _messages[index] = updated;
                                      }
                                    });
                                  },
                                ),
                              if (msg.scheduleActionData != null)
                                ScheduleChangeCard(
                                  key: ValueKey('schedule-' + msg.id),
                                  message: msg,
                                ),
                              if (msg.source == 'groq_cloud' ||
                                  msg.source == 'ai_cloud')
                                const _TutorCaveat(),
                              if (msg.truncated)
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.content_cut_rounded,
                                        size: 14,
                                        color: MochiPalette.of(context).muted,
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Câu trả lời có thể bị cắt vì giới hạn độ dài.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: MochiPalette.of(context)
                                                .muted,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () => _sendMessage(
                                                'Viết tiếp phần còn lại của câu trả lời trước.',
                                              ),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                        ),
                                        child: Text('Viết tiếp'),
                                      ),
                                    ],
                                  ),
                                ),
                              if (msg.source == 'authentication_required')
                                Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: FilledButton.tonalIcon(
                                    onPressed: _requestLogin,
                                    icon: Icon(Icons.login_rounded, size: 16),
                                    label: Text('Đăng nhập ngay'),
                                  ),
                                ),
                              if (msg.source == 'unavailable')
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: MochiPalette.of(context)
                                                .muted,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Chưa kết nối được AI',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: MochiPalette.of(context)
                                                  .muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (msg.failureReason ==
                                          'session_expired')
                                        FilledButton.tonalIcon(
                                          onPressed: _requestLogin,
                                          icon: Icon(
                                            Icons.login_rounded,
                                            size: 16,
                                          ),
                                          label: Text('Đăng nhập lại'),
                                        )
                                      else if (AIService.isRetryableReason(
                                        msg.failureReason,
                                      ))
                                        TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : () {
                                                  final question = _messages
                                                      .lastWhere(
                                                        (m) => m.role == 'user',
                                                      )
                                                      .content;
                                                  _sendMessage(question);
                                                },
                                          child: Text('Thử lại'),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Quick prompts floating at top
              if (constraints.maxHeight > 300)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ClipRect(
                    child: RepaintBoundary(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontal,
                          vertical: 8,
                        ),
                        color: MochiPalette.of(context).pageTop
                            .withValues(alpha: 0.85),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _quickPrompts.map((p) {
                              return Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(
                                    p,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: MochiPalette.of(context).ink,
                                    ),
                                  ),
                                  backgroundColor: accent.withValues(
                                    alpha: 0.08,
                                  ),
                                  side: BorderSide(
                                    color: accent.withValues(alpha: 0.2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  onPressed: () => _sendMessage(p),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Layer 1: Liquid Glass Floating Composer (Transparent background, no gray blocks)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      Container(
                        margin: EdgeInsets.only(bottom: 6),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: MochiPalette.of(context).card
                              .withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Mình đang xem câu hỏi của bạn…',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MochiPalette.of(context).muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            TextButton(
                              onPressed: _cancelRequest,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: Text('Huỷ'),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      margin: EdgeInsets.fromLTRB(
                        horizontal,
                        0,
                        horizontal,
                        effectiveBottom,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: RepaintBoundary(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: isHighContrast
                                  ? null
                                  : PastelPalette.of(context).cardGradient,
                              color: isHighContrast
                                  ? MochiPalette.of(context).card
                                  : null,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: MochiPalette.of(context).cardBorder
                                    .withValues(alpha: 0.85),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: MochiPalette.of(context).ink
                                      .withValues(alpha: 0.10),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_attachedImage != null)
                                  Container(
                                    margin: EdgeInsets.only(bottom: 6),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MochiPalette.of(context).cardSoft
                                          .withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: MochiPalette.of(context)
                                            .cardBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.image_outlined,
                                          size: 18,
                                          color: accent,
                                        ),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _attachedImage!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.close, size: 16),
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _attachedImage = null;
                                              _attachedImageBase64 = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Gửi ảnh đề bài',
                                      icon: Icon(
                                        Icons.camera_alt_outlined,
                                        color: MochiPalette.of(context).muted,
                                        size: 22,
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              final source =
                                                  await showModalBottomSheet<
                                                    ImageSource
                                                  >(
                                                    context: context,
                                                    builder: (ctx) => SafeArea(
                                                      child: Wrap(
                                                        children: [
                                                          ListTile(
                                                            leading: Icon(
                                                              Icons
                                                                  .camera_alt_outlined,
                                                            ),
                                                            title: Text(
                                                              'Chụp ảnh đề bài',
                                                            ),
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  ImageSource
                                                                      .camera,
                                                                ),
                                                          ),
                                                          ListTile(
                                                            leading: Icon(
                                                              Icons
                                                                  .photo_library_outlined,
                                                            ),
                                                            title: Text(
                                                              'Chọn ảnh từ thư viện',
                                                            ),
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  ImageSource
                                                                      .gallery,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                              if (source != null) {
                                                final picker = ImagePicker();
                                                final file = await picker
                                                    .pickImage(
                                                      source: source,
                                                      maxWidth: 1600,
                                                      maxHeight: 1600,
                                                      imageQuality: 85,
                                                    );
                                                if (file != null) {
                                                  final bytes = await file
                                                      .readAsBytes();
                                                  setState(() {
                                                    _attachedImage = file;
                                                    _attachedImageBase64 =
                                                        'data:image/jpeg;base64,' +
                                                        base64Encode(bytes);
                                                  });
                                                }
                                              }
                                            },
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _msgController,
                                        onTapOutside: (_) => FocusManager
                                            .instance
                                            .primaryFocus
                                            ?.unfocus(),
                                        textInputAction: TextInputAction.send,
                                        maxLines: 3,
                                        minLines: 1,
                                        decoration: InputDecoration(
                                          hintText: 'Hỏi Mochi…',
                                          isDense: true,
                                          filled: false,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          border: InputBorder.none,
                                        ),
                                        onSubmitted: (_) => _sendMessage(),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_upward_rounded,
                                        color: MochiPalette.of(context)
                                            .onAccent,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: accent,
                                        shape: CircleBorder(),
                                      ),
                                      tooltip: 'Gửi câu hỏi',
                                      onPressed: _isLoading
                                          ? null
                                          : () => _sendMessage(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Nhắc ngắn, giống nhau ở mọi câu trả lời do AI tạo: nội dung có thể sai.
class _TutorCaveat extends StatelessWidget {
  const _TutorCaveat();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.verified_outlined,
          size: 13,
          color: MochiPalette.of(context).muted,
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            'AI có thể sai. Hãy kiểm chứng với SGK hoặc giáo viên trước khi dùng.',
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: MochiPalette.of(context).muted,
            ),
          ),
        ),
      ],
    ),
  );
}
