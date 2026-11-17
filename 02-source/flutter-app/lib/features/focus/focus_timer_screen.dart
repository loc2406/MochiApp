import '../../design/mochi_design.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../core/services/notification_service.dart';
import '../robot/robot_mascot_widget.dart';
import '../ai_tutor/ai_tutor_sheet.dart';

class FocusTimerScreen extends StatefulWidget {
  final TaskModel? targetTask;
  final String? learningBlockId;

  const FocusTimerScreen({super.key, this.targetTask, this.learningBlockId});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with WidgetsBindingObserver {
  DateTime? _deadline;
  final String _sessionOperationKey =
      'focus_${DateTime.now().microsecondsSinceEpoch}';
  bool get _countdown => _isPomodoro || _customFreestyleMinutes > 0;
  bool _isPomodoro = true;
  PomodoroPhase _phase = PomodoroPhase.focus;

  int _focusMinutes = 25;
  final int _breakMinutes = 5;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  int _timerEpoch = 0;
  Timer? _timer;

  int _stopwatchSeconds = 0;
  DateTime? _stopwatchStarted;
  int _stopwatchBaseSeconds = 0;
  Timer? _stopwatchTimer;

  int _activeMinutesAccumulated = 0;
  int _customFreestyleMinutes =
      0; // 0 = đếm tiến vô hạn, >0 = đếm lùi có chuông nhắc

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.targetTask != null) {
      _focusMinutes = widget.targetTask!.durationMinutes;
      _remainingSeconds = _focusMinutes * 60;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  Future<void> _editDuration() async {
    final ctrl = TextEditingController(
      text: _countdown ? _focusMinutes.toString() : '',
    );
    final formKey = GlobalKey<FormState>();
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) {
        void apply() {
          if (formKey.currentState!.validate()) {
            Navigator.pop(ctx, int.parse(ctrl.text.trim()));
          }
        }

        return AlertDialog(
          title: Text('Đặt thời lượng học'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isRunning)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Áp dụng sẽ dừng phiên hiện tại và đặt lại đồng hồ. Chuông báo cũ sẽ được hủy.',
                    ),
                  ),
                TextFormField(
                  key: ValueKey('timer-duration-input'),
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Số phút',
                    helperText: 'Nhập từ 1 đến 180 phút',
                    suffixText: 'phút',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final n = int.tryParse(value?.trim() ?? '');
                    return n == null || n < 1 || n > 180
                        ? 'Nhập số phút từ 1 đến 180'
                        : null;
                  },
                  onFieldSubmitted: (_) => apply(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
            MochiPrimaryButton(onPressed: apply, child: Text('Áp dụng')),
          ],
        );
      },
    );
    // The dialog route finishes its exit animation before disposing its controller.
    await Future<void>.delayed(Duration(milliseconds: 300));
    ctrl.dispose();
    if (minutes == null || !mounted) return;
    _pauseTimer();
    setState(() {
      _focusMinutes = minutes;
      if (!_isPomodoro) _customFreestyleMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _stopwatchSeconds = 0;
      _activeMinutesAccumulated = 0;
      _phase = PomodoroPhase.focus;
    });
  }

  Future<void> _startTimer() async {
    if (_isRunning) return;
    final notices = NotificationService();
    if (_countdown && NotificationService.supported) {
      if (!await notices.notificationsEnabled())
        await notices.requestPermission();
      if (!await notices.exactAlarmsEnabled())
        await notices.requestExactAlarms();
      if (!mounted) return;
      if (!await notices.notificationsEnabled() ||
          !await notices.exactAlarmsEnabled()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cần cho phép thông báo và báo thức chính xác để nhắc hết giờ khi chạy nền. Bật quyền rồi nhấn bắt đầu lại.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    if (_isRunning) return;
    HapticFeedback.mediumImpact();
    final epoch = ++_timerEpoch;
    setState(() => _isRunning = true);
    context.read<MochiStore>().setRobotEmotion(RobotEmotion.focus);

    // Hẹn chuông báo native background đúng thời điểm hết giờ
    final secsToRemind = _isPomodoro
        ? _remainingSeconds
        : (_customFreestyleMinutes > 0 ? _remainingSeconds : 0);
    if (secsToRemind > 0) {
      final scheduled = await NotificationService()
          .scheduleTimerEndNotification(
            secondsFromNow: secsToRemind,
            taskTitle: widget.targetTask?.title ?? 'Tự học',
            isBreak: _phase != PomodoroPhase.focus,
          );
      if (!mounted) return;
      if (!_isRunning || epoch != _timerEpoch) {
        await notices.cancelTimerEndNotification();
        return;
      }
      if (!scheduled) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chưa đặt được chuông hết giờ. Kiểm tra quyền thông báo rồi thử lại.',
            ),
          ),
        );
        return;
      }
    }

    if (_countdown) {
      _deadline = DateTime.now().add(Duration(seconds: _remainingSeconds));
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          final left = _deadline!.difference(DateTime.now()).inMilliseconds;
          setState(
            () => _remainingSeconds = ((left + 999) ~/ 1000).clamp(0, 86400),
          );
          if (_phase == PomodoroPhase.focus && _remainingSeconds % 60 == 0) {
            _activeMinutesAccumulated++;
          }
        } else {
          _timer?.cancel();
          _onPomodoroPhaseComplete();
        }
      });
    } else {
      _stopwatchBaseSeconds = _stopwatchSeconds;
      _stopwatchStarted = DateTime.now();
      _stopwatchTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _stopwatchSeconds =
              _stopwatchBaseSeconds +
              DateTime.now().difference(_stopwatchStarted!).inSeconds;
          _activeMinutesAccumulated = _stopwatchSeconds ~/ 60;
        });
      });
    }
  }

  void _pauseTimer() {
    _timerEpoch++;
    if (_isRunning && !_countdown && _stopwatchStarted != null) {
      _stopwatchSeconds =
          _stopwatchBaseSeconds +
          DateTime.now().difference(_stopwatchStarted!).inSeconds;
      _activeMinutesAccumulated = _stopwatchSeconds ~/ 60;
    }
    _stopwatchStarted = null;
    _deadline = null;
    NotificationService().cancelTimerEndNotification();
    HapticFeedback.lightImpact();
    _timer?.cancel();
    _stopwatchTimer?.cancel();
    setState(() => _isRunning = false);
    context.read<MochiStore>().setRobotEmotion(RobotEmotion.idle);
  }

  void _resetTimer() {
    HapticFeedback.selectionClick();
    _pauseTimer();
    setState(() {
      _remainingSeconds = _focusMinutes * 60;
      _stopwatchSeconds = 0;
      _phase = PomodoroPhase.focus;
    });
  }

  void _onPomodoroPhaseComplete() {
    _deadline = null;
    NotificationService().cancelTimerEndNotification();
    setState(() => _isRunning = false);
    NotificationService().showTimerComplete(
      isBreak:
          _phase == PomodoroPhase.shortBreak ||
          _phase == PomodoroPhase.longBreak,
      taskTitle: widget.targetTask?.title ?? 'Tự học',
    );
    if (_phase == PomodoroPhase.focus) {
      if (_countdown) _activeMinutesAccumulated = _focusMinutes;
      _showSessionCompletionDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hết giờ nghỉ! Sẵn sàng cho phiên tập trung tiếp theo chưa?',
          ),
        ),
      );
      setState(() {
        _phase = PomodoroPhase.focus;
        _remainingSeconds = _focusMinutes * 60;
      });
    }
  }

  void _finishSessionEarly() {
    HapticFeedback.selectionClick();
    _pauseTimer();
    final activeMins = _countdown
        ? ((_focusMinutes * 60 - _remainingSeconds) / 60).floor()
        : (_stopwatchSeconds / 60).floor();

    if (activeMins < 1) {
      Navigator.pop(context);
      return;
    }

    _activeMinutesAccumulated = activeMins;
    _showSessionCompletionDialog();
  }

  void _showSessionCompletionDialog() async {
    final store = context.read<MochiStore>();
    int rating = 5;
    final reflectionCtrl = TextEditingController();

    final aiRecapFuture = store.aiService.generateSessionRecap(
      taskTitle: widget.targetTask?.title ?? 'Phiên học tự do',
      minutesSpent: _activeMinutesAccumulated.clamp(1, 180),
      selfRating: rating,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: RobotMascotWidget(
                    size: 90,
                    emotion: RobotEmotion.celebrate,
                    primaryColor: Color(store.robotColorHex),
                  ),
                ),
                SizedBox(height: 12),
                Center(
                  child: Text(
                    'Chúc mừng! Hoàn thành xuất sắc (+${(_activeMinutesAccumulated >= 20 ? 2 : 1)} sao, +${_activeMinutesAccumulated * 5} XP)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: MochiPalette.of(context).ink,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Bạn vừa hoàn thành $_activeMinutesAccumulated phút học tập chất lượng!',
                    style: TextStyle(
                      fontSize: 13,
                      color: MochiPalette.of(context).muted,
                    ),
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Tự đánh giá mức độ tập trung:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIdx = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIdx <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: MochiPalette.of(context).warning,
                        size: 34,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setSheetState(() => rating = starIdx);
                      },
                    );
                  }),
                ),
                SizedBox(height: 12),
                Text(
                  'Ghi chú bài học hoặc suy ngẫm:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: reflectionCtrl,
                  decoration: InputDecoration(
                    hintText: 'Hôm nay mình đã nắm vững kiến thức...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>>(
                  future: aiRecapFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: MochiPalette.of(context).action,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Mochi AI đang chuẩn bị tổng kết phiên học...',
                              style: TextStyle(
                                fontSize: 12,
                                color: MochiPalette.of(context).muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (snap.hasData) {
                      final summary = snap.data!['summary'] ?? '';
                      return Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: MochiPalette.of(context).action
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: MochiPalette.of(context).action
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          summary,
                          style: TextStyle(
                            fontSize: 13,
                            color: MochiPalette.of(context).ink,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: MochiPrimaryButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      store.completeStudySession(
                        taskId: widget.targetTask?.id ?? '',
                        taskTitle: widget.targetTask?.title ?? 'Tự học',
                        mode: _isPomodoro ? 'pomodoro' : 'freestyle',
                        activeMinutes: _activeMinutesAccumulated.clamp(1, 180),
                        selfRating: rating,
                        reflection: reflectionCtrl.text.trim(),
                        operationKey: _sessionOperationKey,
                        learningBlockId: widget.learningBlockId,
                        completeTask: widget.learningBlockId == null,
                      );
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MochiPalette.of(context).accent,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Lưu vào nhật ký học tập',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: MochiPalette.of(context).onAccent,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final taskName = widget.targetTask?.title ?? 'Phiên học tự do';
    final subject = widget.targetTask?.subject ?? 'Tập trung';

    final minutes = _countdown
        ? (_remainingSeconds ~/ 60)
        : (_stopwatchSeconds ~/ 60);
    final seconds = _countdown
        ? (_remainingSeconds % 60)
        : (_stopwatchSeconds % 60);
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final totalSecs = _phase == PomodoroPhase.focus
        ? (_focusMinutes * 60)
        : (_breakMinutes * 60);
    final progress = _countdown
        ? (1.0 - (_remainingSeconds / totalSecs)).clamp(0.0, 1.0)
        : 1.0;

    return MochiScaffold(
      appBar: MochiAppBar.detail(
        title: subject,
        automaticallyImplyLeading: false,
        leading: MochiIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Quay lại',
          filled: false,
          onPressed: () {
            if (_isRunning) {
              _finishSessionEarly();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          MochiIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Hỏi Mochi AI',
            filled: false,
            onPressed: () {
              HapticFeedback.selectionClick();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => AITutorSheet(taskContext: widget.targetTask),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive diameter responsive to both width & height
            final timerDiameter = math
                .min(constraints.maxWidth * 0.65, constraints.maxHeight * 0.36)
                .clamp(160.0, 230.0);
            final mascotSize = (constraints.maxHeight * 0.16).clamp(
              65.0,
              110.0,
            );

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Mode switch pills
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: MochiSegmentedControl<String>(
                              value: _isPomodoro ? 'pomodoro' : 'free',
                              segments: const [
                                MochiSegment(
                                  value: 'pomodoro',
                                  label: 'Pomodoro',
                                  icon: Icons.timer_outlined,
                                ),
                                MochiSegment(
                                  value: 'free',
                                  label: 'Bấm giờ tự do',
                                  icon: Icons.av_timer_rounded,
                                ),
                              ],
                              onChanged: _isRunning
                                  ? null
                                  : (value) => setState(
                                      () => _isPomodoro = value == 'pomodoro',
                                    ),
                            ),
                          ),
                        ),

                        // Bộ chọn thời gian hẹn giờ cho chế độ Tự do
                        if (!_isPomodoro && !_isRunning)
                          Padding(
                            padding: EdgeInsets.only(top: 4, bottom: 8),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              runSpacing: 8,
                              children: [
                                _buildFreestylePresetChip('Đếm tiến', 0),
                                _buildFreestylePresetChip('15p', 15),
                                _buildFreestylePresetChip('30p', 30),
                                _buildFreestylePresetChip('45p', 45),
                                _buildFreestylePresetChip('60p', 60),
                              ],
                            ),
                          ),

                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: MochiButton(
                            key: ValueKey('timer-duration'),
                            label: _countdown
                                ? 'Đặt thời lượng · $_focusMinutes phút'
                                : 'Đặt thời lượng · Đếm tiến',
                            icon: Icons.timer_outlined,
                            variant: MochiButtonVariant.secondary,
                            onPressed: _editDuration,
                          ),
                        ),

                        Spacer(),

                        // Mascot
                        RobotMascotWidget(
                          size: mascotSize,
                          emotion: _isRunning
                              ? RobotEmotion.focus
                              : RobotEmotion.idle,
                          primaryColor: Color(store.robotColorHex),
                          equippedAccessory: store.equippedAccessory,
                          equippedClothes: store.equippedClothes,
                          equippedSpecial: store.equippedSpecial,
                        ),
                        SizedBox(height: 12),

                        // Target Task Title
                        Text(
                          taskName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: MochiPalette.of(context).ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          _phase == PomodoroPhase.focus
                              ? 'Phiên tập trung cao độ'
                              : 'Giờ nghỉ ngơi thư giãn',
                          style: TextStyle(
                            color: _phase == PomodoroPhase.focus
                                ? MochiPalette.of(context).action
                                : MochiPalette.of(context).success,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        SizedBox(height: 18),

                        // Adaptive Circular Timer Ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: timerDiameter,
                              height: timerDiameter,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: timerDiameter * 0.045,
                                backgroundColor: MochiPalette.of(context).action
                                    .withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _phase == PomodoroPhase.focus
                                      ? MochiPalette.of(context).warning
                                      : MochiPalette.of(context).success,
                                ),
                              ),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: MochiPalette.of(context).ink,
                                fontSize: timerDiameter * 0.22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),

                        Spacer(),

                        // Bottom Controls
                        Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MochiIconButton(
                                icon: Icons.refresh_rounded,
                                iconSize: 28,
                                tooltip: 'Đặt lại đồng hồ',
                                filled: false,
                                onPressed: _resetTimer,
                              ),
                              SizedBox(width: 24),
                              MochiIconButton(
                                icon: _isRunning
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                iconSize: 36,
                                size: 76,
                                color: MochiPalette.of(context).onAccent,
                                background: _isRunning
                                    ? MochiPalette.of(context).danger
                                    : MochiPalette.of(context).success,
                                tooltip: _isRunning
                                    ? 'Tạm dừng'
                                    : 'Bắt đầu',
                                onPressed: _isRunning
                                    ? _pauseTimer
                                    : _startTimer,
                              ),
                              SizedBox(width: 24),
                              MochiIconButton(
                                icon: Icons.stop_circle_outlined,
                                iconSize: 28,
                                tooltip: 'Kết thúc phiên',
                                filled: false,
                                onPressed: _finishSessionEarly,
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
          },
        ),
      ),
    );
  }

  Widget _buildFreestylePresetChip(String label, int mins) {
    final isSelected = _customFreestyleMinutes == mins;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MochiFilterChip(
        label: label,
        selected: isSelected,
        onSelected: (selected) {
          if (!selected) return;
          setState(() {
            _customFreestyleMinutes = mins;
            if (mins > 0) {
              _focusMinutes = mins;
              _remainingSeconds = mins * 60;
            } else {
              _stopwatchSeconds = 0;
            }
          });
        },
      ),
    );
  }
}
